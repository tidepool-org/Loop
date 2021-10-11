//
//  VersionCheckServicesManager.swift
//  Loop
//
//  Created by Rick Pasetto on 9/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Combine
import Foundation
import LoopKit
import LoopKitUI
import SwiftUI

public final class VersionCheckServicesManager {
    private static var alertCadence = TimeInterval.days(14) // every 2 weeks
    
    private lazy var log = DiagnosticLog(category: "VersionCheckServicesManager")
    private lazy var dispatchQueue = DispatchQueue(label: "com.loopkit.Loop.VersionCheckServicesManager", qos: .background)

    // Only one VersionCheckService allowed at a time (last one wins)
    private var versionCheckService = Locked<VersionCheckService?>(nil)
    
    private let alertIssuer: AlertIssuer
    
    lazy private var cancellables = Set<AnyCancellable>()

    init(alertIssuer: AlertIssuer) {
        self.alertIssuer = alertIssuer
        
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
        self.versionCheckService.mutate { $0 = versionCheckService }
    }

    func restoreService(_ versionCheckService: VersionCheckService) {
        self.versionCheckService.mutate { $0 = versionCheckService }
    }

    func removeService(_ versionCheckService: VersionCheckService) {
        self.versionCheckService.mutate {
            if $0?.serviceIdentifier == versionCheckService.serviceIdentifier {
                $0 = nil
            }
        }
    }
    
    public func performCheck() {
        checkVersion { [self] versionUpdate in
            notify(versionUpdate)
        }
    }

    private func notify(_ versionUpdate: VersionUpdate) {
        if versionUpdate.softwareUpdateAvailable {
            NotificationCenter.default.post(name: .SoftwareUpdateAvailable, object: versionUpdate)
        }
//        maybeIssueAlert(versionUpdate)
    }
    
    public func softwareUpdateView(guidanceColors: GuidanceColors) -> AnyView? {
        guard let versionCheckServiceUI = versionCheckService.value as? VersionCheckServiceUI else {
            return nil
        }
        return versionCheckServiceUI.softwareUpdateView(
            guidanceColors: guidanceColors,
            bundleIdentifier: Bundle.main.bundleIdentifier!,
            currentVersion: Bundle.main.shortVersionString,
            openAppStoreHook: openAppStore)
    }

//    private func maybeIssueAlert(_ versionUpdate: VersionUpdate) {
//        guard versionUpdate >= .recommended else {
//            noAlertNecessary()
//            return
//        }
//
//        let alertIdentifier = Alert.Identifier(managerIdentifier: "VersionCheckServicesManager", alertIdentifier: versionUpdate.rawValue)
//        let alertContent: Alert.Content
//        if firstAlert {
//            alertContent = Alert.Content(title: versionUpdate.alertTitle,
//                                         body: NSLocalizedString("""
//                                            Your Tidepool Loop app is out of date. It will continue to work, but we recommend updating to the latest version.
//
//                                            Go to Tidepool Loop Settings > Software Update to complete.
//                                            """, comment: "Alert content body for first software update alert"),
//                                         acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "default acknowledgement"),
//                                         isCritical: versionUpdate == .required)
//        } else if let lastVersionCheckAlertDate = UserDefaults.appGroup?.lastVersionCheckAlertDate,
//                  abs(lastVersionCheckAlertDate.timeIntervalSinceNow) > Self.alertCadence {
//            alertContent = Alert.Content(title: NSLocalizedString("Update Reminder", comment: "Recurring software update alert title"),
//                                         body: NSLocalizedString("""
//                                            A software update is recommended to continue using the Tidepool Loop app.
//
//                                            Go to Tidepool Loop Settings > Software Update to install the latest version.
//                                            """, comment: "Alert content body for recurring software update alert"),
//                                         acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "default acknowledgement"),
//                                         isCritical: versionUpdate == .required)
//        } else {
//            return
//        }
//        alertIssuer.issueAlert(Alert(identifier: alertIdentifier, foregroundContent: alertContent, backgroundContent: alertContent, trigger: .immediate))
//        recordLastAlertDate()
//    }
//
//    private func noAlertNecessary() {
//        UserDefaults.appGroup?.lastVersionCheckAlertDate = nil
//    }
//
//    private var firstAlert: Bool {
//        return UserDefaults.appGroup?.lastVersionCheckAlertDate == nil
//    }
//
//    private func recordLastAlertDate() {
//        UserDefaults.appGroup?.lastVersionCheckAlertDate = Date()
//    }
    
    func checkVersion(completion: @escaping (VersionUpdate) -> Void) {
        if let service = versionCheckService.value {
            dispatchQueue.async {
                service.checkVersion(bundleIdentifier: Bundle.main.bundleIdentifier!, currentVersion: Bundle.main.shortVersionString) {
                    completion($0.value)
                }
            }
        } else {
            completion(.none)
        }
    }
}

extension VersionCheckServicesManager {
    public func openAppStore() {
        if let appStoreURLString = Bundle.main.appStoreURL,
            let appStoreURL = URL(string: appStoreURLString) {
            UIApplication.shared.open(appStoreURL)
        }
    }
}

extension VersionUpdate {
    var alertTitle: String { return self.localizedDescription }
}

fileprivate extension Result where Success == VersionUpdate? {
    var value: VersionUpdate {
        switch self {
        case .failure: return .none
        case .success(let val): return val ?? .none
        }
    }
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
