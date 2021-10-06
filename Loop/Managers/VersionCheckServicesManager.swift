//
//  VersionCheckServicesManager.swift
//  Loop
//
//  Created by Rick Pasetto on 9/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Combine
import UIKit
import Foundation
import LoopKit

public final class VersionCheckServicesManager {
    private static var alertCadence = TimeInterval.minutes(1)// TimeInterval.days(14) // every 2 weeks
    
    private lazy var log = DiagnosticLog(category: "VersionCheckServicesManager")
    private lazy var dispatchQueue = DispatchQueue(label: "com.loopkit.Loop.VersionCheckServicesManager")

    private var versionCheckServices = Locked<[VersionCheckService]>([])
    
    private let alertManager: AlertManager
    
    lazy private var cancellables = Set<AnyCancellable>()

    init(alertManager: AlertManager) {
        self.alertManager = alertManager
        
        // Perform a check every foreground entry and every loop
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.performCheck()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .LoopCompleted)
            .sink { [weak self] _ in
                self?.performCheck()
            }
            .store(in: &cancellables)
    }

    func addService(_ versionCheckService: VersionCheckService) {
        versionCheckServices.mutate { $0.append(versionCheckService) }
    }

    func restoreService(_ versionCheckService: VersionCheckService) {
        versionCheckServices.mutate { $0.append(versionCheckService) }
    }

    func removeService(_ versionCheckService: VersionCheckService) {
        versionCheckServices.mutate { $0.removeAll { $0.serviceIdentifier == versionCheckService.serviceIdentifier } }
    }
    
    public func performCheck() {
        if #available(iOS 15.0.0, *) {
            Task {
                let versionUpdate = await checkVersion(currentVersion: Bundle.main.shortVersionString)
                notify(versionUpdate)
            }
        } else {
            checkVersion(currentVersion: Bundle.main.shortVersionString) { [self] versionUpdate in
                notify(versionUpdate)
            }
        }
    }
    
    private func notify(_ versionUpdate: VersionUpdate) {
        if versionUpdate.softwareUpdateAvailable {
            NotificationCenter.default.post(name: .SoftwareUpdateAvailable, object: versionUpdate)
        }
        maybeIssueAlert(versionUpdate)
    }
    
    private func maybeIssueAlert(_ versionUpdate: VersionUpdate) {
        // For now, we only issue alerts for recommended or higher
        guard versionUpdate >= .supportedNeeded else {
            noAlertNecessary()
            return
        }
        
        let alertIdentifier = Alert.Identifier(managerIdentifier: "VersionCheckServicesManager", alertIdentifier: versionUpdate.rawValue)
        let alertContent: Alert.Content
        if firstAlert {
            alertContent = Alert.Content(title: versionUpdate.alertTitle,
                                         body: NSLocalizedString("""
                                            Your Tidepool Loop app is out of date. It will continue to work, but we recommend updating to the latest version.
                                            
                                            Go to Tidepool Loop Settings > Software Update to complete.
                                            """, comment: "Alert content body for first software update alert"),
                                         acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "default acknowledgement"),
                                         isCritical: versionUpdate == .criticalNeeded)
        } else if let lastVersionCheckAlertDate = UserDefaults.appGroup?.lastVersionCheckAlertDate,
                  abs(lastVersionCheckAlertDate.timeIntervalSinceNow) > Self.alertCadence {
            alertContent = Alert.Content(title: NSLocalizedString("Update Reminder", comment: "Recurring software update alert title"),
                                         body: NSLocalizedString("""
                                            A software update is recommended to continue using the Tidepool Loop app.
                                            
                                            Go to Tidepool Loop Settings > Software Update to install the latest version.
                                            """, comment: "Alert content body for recurring software update alert"),
                                         acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "default acknowledgement"),
                                         isCritical: versionUpdate == .criticalNeeded)
        } else {
            return
        }
        alertManager.issueAlert(Alert(identifier: alertIdentifier, foregroundContent: alertContent, backgroundContent: alertContent, trigger: .immediate))
        recordLastAlertDate()
    }
    
    private func noAlertNecessary() {
        UserDefaults.appGroup?.lastVersionCheckAlertDate = nil
    }
    
    private var firstAlert: Bool {
        return UserDefaults.appGroup?.lastVersionCheckAlertDate == nil
    }
    
    private func recordLastAlertDate() {
        UserDefaults.appGroup?.lastVersionCheckAlertDate = Date()
    }
    
    @available(swift 5.5)
    @available(iOS 15.0.0, *)
    func checkVersion(currentVersion: String) async -> VersionUpdate {
        var results = [String: Result<VersionUpdate?, Error>]()
        let services = versionCheckServices.value
        await withTaskGroup(of: (String, Result<VersionUpdate?, Error>).self) { group in
            for service in services {
                group.addTask {
                    let result = await service.checkVersion(bundleIdentifier: Bundle.main.bundleIdentifier!, currentVersion: currentVersion)
                    return (service.serviceIdentifier, result)
                }
            }
            for await pair in group {
                results[pair.0] = pair.1
            }
        }
        return aggregate(results: results)
    }

    @available(swift 5.5)
    @available(iOS 15.0.0, *)
    func checkVersion(currentVersion: String, completion: @escaping (VersionUpdate) -> Void) async {
        Task {
            let versionUpdate = await checkVersion(currentVersion: Bundle.main.shortVersionString)
            completion(versionUpdate)
        }
    }

    @available(iOS, deprecated: 15.0.0)
    func checkVersion(currentVersion: String, completion: @escaping (VersionUpdate) -> Void) {
        let group = DispatchGroup()
        var results = [String: Result<VersionUpdate?, Error>]()
        let services = versionCheckServices.value
        services.forEach { versionCheckService in
            group.enter()
            versionCheckService.checkVersion(bundleIdentifier: Bundle.main.bundleIdentifier!, currentVersion: currentVersion) { result in
                results[versionCheckService.serviceIdentifier] = result
                group.leave()
            }
        }
        group.notify(queue: dispatchQueue) {
            completion(self.aggregate(results: results))
        }
    }

    private func aggregate(results: [String : Result<VersionUpdate?, Error>]) -> VersionUpdate {
        var aggregatedVersionUpdate = VersionUpdate.default
        results.forEach { key, value in
            switch value {
            case .failure(let error):
                self.log.error("Error from version check service %{public}@: %{public}@", key, error.localizedDescription)
            case .success(let versionUpdate):
                if let versionUpdate = versionUpdate, versionUpdate > aggregatedVersionUpdate {
                    aggregatedVersionUpdate = versionUpdate
                }
            }
        }
        return aggregatedVersionUpdate
    }
}

extension VersionCheckService {
    @available(iOS 15.0.0, *)
    func checkVersion(bundleIdentifier: String, currentVersion: String) async -> Result<VersionUpdate?, Error> {
        return await withUnsafeContinuation { continuation in
            self.checkVersion(bundleIdentifier: bundleIdentifier, currentVersion: currentVersion) {
                continuation.resume(returning: $0)
            }
        }
    }
}

extension Notification.Name {
    static let SoftwareUpdateAvailable = Notification.Name(rawValue: "com.loopkit.Loop.SoftwareUpdateAvailable")
}

extension VersionUpdate {
    var softwareUpdateAvailable: Bool { self != .noneNeeded }
    
    var alertTitle: String { return self.localizedDescription }
}

fileprivate extension UserDefaults {
    private enum Key: String {
        case lastVersionCheckAlertDate = "com.loopkit.Loop.lastVersionCheckAlertDate"
    }

    var lastVersionCheckAlertDate: Date? {
        get {
            return object(forKey: Key.lastVersionCheckAlertDate.rawValue) as? Date
        }
        set {
            set(newValue, forKey: Key.lastVersionCheckAlertDate.rawValue)
        }
    }
}
