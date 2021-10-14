//
//  SupportManager.swift
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
import MockKitUI

public final class SupportManager {
    
    private lazy var log = DiagnosticLog(category: "SupportManager")

    private var supports = Locked<[String: SupportUI]>([:])
    
    private var identifierWithHighestVersionUpdate: String? {
        get {
            return UserDefaults.appGroup?.identifierWithHighestVersionUpdate
        }
        set {
            UserDefaults.appGroup?.identifierWithHighestVersionUpdate = newValue
        }
    }
    
    private let alertIssuer: AlertIssuer
    private let pluginManager: PluginManager
    private let deviceDataManager: DeviceDataManager
    private let servicesManager: ServicesManager

    lazy private var cancellables = Set<AnyCancellable>()

    init(pluginManager: PluginManager, deviceDataManager: DeviceDataManager, servicesManager: ServicesManager, alertIssuer: AlertIssuer) {
        self.alertIssuer = alertIssuer
        self.pluginManager = pluginManager
        self.deviceDataManager = deviceDataManager
        self.servicesManager = servicesManager
        
        restoreState()

        (pluginManager.availableSupports +
         deviceDataManager.availableSupports +
         servicesManager.availableSupports +
         staticSupportTypes.map { $0.init(rawState: [:]) }.compactMap { $0 })
            .forEach {
                addSupport($0)
            }
                
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
}

// MARK: Manage list of Supports
extension SupportManager {
    func addSupport(_ support: SupportUI) {
        supports.mutate {
            if $0[support.identifier] == nil {
                $0[support.identifier] = support
                support.setAlertIssuer(alertIssuer: alertIssuer)
            }
        }
    }

    func restoreSupport(_ support: SupportUI) {
        addSupport(support)
    }

    func removeSupport(_ support: SupportUI) {
        supports.mutate {
            $0[support.identifier] = nil
            support.setAlertIssuer(alertIssuer: nil)
        }
    }
    
    var availableSupports: [SupportUI] {
        return Array(supports.value.values)
    }
}

// MARK: Version checking
extension SupportManager {
    func performCheck() {
        checkVersion { [self] versionUpdate in
            notify(versionUpdate)
        }
    }
    
    private func notify(_ versionUpdate: VersionUpdate) {
        if versionUpdate.softwareUpdateAvailable {
            NotificationCenter.default.post(name: .SoftwareUpdateAvailable, object: versionUpdate)
        }
    }
        
    func checkVersion(completion: @escaping (VersionUpdate) -> Void) {
        let group = DispatchGroup()
        var results = [String: Result<VersionUpdate?, Error>]()
        supports.value.values.forEach { support in
            group.enter()
            support.checkVersion(bundleIdentifier: Bundle.main.bundleIdentifier!, currentVersion: Bundle.main.shortVersionString) { result in
                results[support.identifier] = result
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else { return }
            self.saveState()
            let aggregatedResults = self.aggregate(results: results)
            self.identifierWithHighestVersionUpdate = aggregatedResults.0
            completion(aggregatedResults.1)
        }
    }

    private func aggregate(results: [String : Result<VersionUpdate?, Error>]) -> (String?, VersionUpdate) {
        var aggregatedVersionUpdate = VersionUpdate.default
        var identifierWithHighestVersionUpdate: String?
        results.forEach { key, value in
            switch value {
            case .failure(let error):
                self.log.error("Error from version check %{public}@: %{public}@", key, error.localizedDescription)
            case .success(let versionUpdate):
                if let versionUpdate = versionUpdate, versionUpdate > aggregatedVersionUpdate {
                    aggregatedVersionUpdate = versionUpdate
                    identifierWithHighestVersionUpdate = key
                }
            }
        }
        return (identifierWithHighestVersionUpdate, aggregatedVersionUpdate)
    }

}

// MARK: UI
extension SupportManager {
    func softwareUpdateView(guidanceColors: GuidanceColors) -> AnyView? {
        // This is the SupportUI that gave the last "highest" VersionUpdate, or `nil` if there is none
        let lastHighestVersionCheckUI =  identifierWithHighestVersionUpdate.flatMap { supports.value[$0] }

        return lastHighestVersionCheckUI?.softwareUpdateView(
            guidanceColors: guidanceColors,
            bundleIdentifier: Bundle.main.bundleIdentifier!,
            currentVersion: Bundle.main.shortVersionString,
            openAppStoreHook: openAppStore)
    }
    
    func openAppStore() {
        if let appStoreURLString = Bundle.main.appStoreURL,
            let appStoreURL = URL(string: appStoreURLString) {
            UIApplication.shared.open(appStoreURL)
        }
    }
}

// MARK: Private functions
extension SupportManager {

    private func saveState() {
        UserDefaults.appGroup?.supportsState = availableSupports.compactMap { $0.rawValue }
    }

    private func restoreState() {
        UserDefaults.appGroup?.supportsState.forEach { rawValue in
            if let support = supportFromRawValue(rawValue) {
                restoreSupport(support)
            }
        }
    }

    private func supportFromRawValue(_ rawValue: SupportUI.RawStateValue) -> SupportUI? {
        guard let supportType = supportTypeFromRawValue(rawValue),
            let rawState = rawValue["state"] as? SupportUI.RawStateValue
            else {
                return nil
        }

        return supportType.init(rawState: rawState)
    }

    private func supportTypeFromRawValue(_ rawValue: [String: Any]) -> SupportUI.Type? {
        guard let supportIdentifier = rawValue["supportIdentifier"] as? String,
              let supportType = pluginManager.getSupportUITypeByIdentifier(supportIdentifier) ?? staticSupportTypesByIdentifier[supportIdentifier]
        else {
            return nil
        }
        
        return supportType
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
        case supportsState = "com.loopkit.Loop.supportsState"
        case identifierWithHighestVersionUpdate = "com.loopkit.Loop.identifierWithHighestVersionUpdate"
    }

    var identifierWithHighestVersionUpdate: String? {
        get {
            return object(forKey: Key.identifierWithHighestVersionUpdate.rawValue) as? String
        }
        set {
            set(newValue, forKey: Key.identifierWithHighestVersionUpdate.rawValue)
        }
    }
    
    var supportsState: [SupportUI.RawStateValue] {
        get {
            return array(forKey: Key.supportsState.rawValue) as? [[String: Any]] ?? []
        }
        set {
            set(newValue, forKey: Key.supportsState.rawValue)
        }
    }

}

let staticSupportTypes: [SupportUI.Type] = {
    FeatureFlags.allowSimulators ? [MockSupport.self] : []
}()

let staticSupportTypesByIdentifier: [String: SupportUI.Type] = staticSupportTypes.reduce(into: [:]) { (map, type) in
    map[type.supportIdentifier] = type
}

extension SupportUI {

    var rawValue: RawStateValue {
        return [
            "supportIdentifier": Self.supportIdentifier,
            "state": rawState
        ]
    }

}
