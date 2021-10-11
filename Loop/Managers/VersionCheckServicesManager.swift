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
    
    private lazy var log = DiagnosticLog(category: "VersionCheckServicesManager")

    private var versionCheckServices = Locked<[VersionCheckService]>([])
    
    private var serviceIdentifierWithHighestVersionUpdate: String? {
        get {
            return UserDefaults.appGroup?.serviceIdentifierWithHighestVersionUpdate
        }
        set {
            UserDefaults.appGroup?.serviceIdentifierWithHighestVersionUpdate = newValue
        }
    }
    
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
        self.versionCheckServices.mutate { $0.append(versionCheckService) }
    }

    func restoreService(_ versionCheckService: VersionCheckService) {
        self.versionCheckServices.mutate { $0.append(versionCheckService) }
    }

    func removeService(_ versionCheckService: VersionCheckService) {
        self.versionCheckServices.mutate { $0.removeAll(where:({ $0.serviceIdentifier == versionCheckService.serviceIdentifier })) }
    }
    
    public func performCheck() {
        checkVersion { [self] versionUpdate in
            notify(versionUpdate)
        }
    }

    private func updateAlertIssuer(_ versionCheckService: VersionCheckService?, _ alertIssuer: AlertIssuer?) {
        guard let versionCheckServiceUI = versionCheckService as? VersionCheckServiceUI else {
            return
        }
        versionCheckServiceUI.setAlertIssuer(alertIssuer: alertIssuer)
    }
    
    private func notify(_ versionUpdate: VersionUpdate) {
        if versionUpdate.softwareUpdateAvailable {
            NotificationCenter.default.post(name: .SoftwareUpdateAvailable, object: versionUpdate)
        }
    }
    
    public func softwareUpdateView(guidanceColors: GuidanceColors) -> AnyView? {
        return lastHighestVersionUpdateService?.softwareUpdateView(
            guidanceColors: guidanceColors,
            bundleIdentifier: Bundle.main.bundleIdentifier!,
            currentVersion: Bundle.main.shortVersionString,
            openAppStoreHook: openAppStore)
    }
    
    // Returns the VersionCheckServiceUI that gave the last "highest" VersionUpdate, or `nil` if there is none
    private var lastHighestVersionUpdateService: VersionCheckServiceUI? {
        return versionCheckServices.value.first {
            $0.serviceIdentifier == serviceIdentifierWithHighestVersionUpdate
        }
        as? VersionCheckServiceUI
    }
    
    func checkVersion(completion: @escaping (VersionUpdate) -> Void) {
        let group = DispatchGroup()
        var results = [String: Result<VersionUpdate?, Error>]()
        let services = versionCheckServices.value
        services.forEach { versionCheckService in
            group.enter()
            versionCheckService.checkVersion(bundleIdentifier: Bundle.main.bundleIdentifier!, currentVersion: Bundle.main.shortVersionString) { result in
                results[versionCheckService.serviceIdentifier] = result
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else { return }
            let aggregatedResults = self.aggregate(results: results)
            self.serviceIdentifierWithHighestVersionUpdate = aggregatedResults.0
            completion(aggregatedResults.1)
        }
    }

    private func aggregate(results: [String : Result<VersionUpdate?, Error>]) -> (String?, VersionUpdate) {
        var aggregatedVersionUpdate = VersionUpdate.default
        var serviceIdentifierWithHighestVersionUpdate: String?
        results.forEach { key, value in
            switch value {
            case .failure(let error):
                self.log.error("Error from version check service %{public}@: %{public}@", key, error.localizedDescription)
            case .success(let versionUpdate):
                if let versionUpdate = versionUpdate, versionUpdate > aggregatedVersionUpdate {
                    aggregatedVersionUpdate = versionUpdate
                    serviceIdentifierWithHighestVersionUpdate = key
                }
            }
        }
        return (serviceIdentifierWithHighestVersionUpdate, aggregatedVersionUpdate)
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
        case serviceIdentifierWithHighestVersionUpdate = "com.loopkit.Loop.serviceIdentifierWithHighestVersionUpdate"
    }

    var serviceIdentifierWithHighestVersionUpdate: String? {
        get {
            return object(forKey: Key.serviceIdentifierWithHighestVersionUpdate.rawValue) as? String
        }
        set {
            set(newValue, forKey: Key.serviceIdentifierWithHighestVersionUpdate.rawValue)
        }
    }
}
