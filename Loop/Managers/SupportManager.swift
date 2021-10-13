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

    private var supports = Locked<[SupportUI]>([])
    
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
    private let mockSupports: [SupportUI]

    lazy private var cancellables = Set<AnyCancellable>()

    init(pluginManager: PluginManager, deviceDataManager: DeviceDataManager, alertIssuer: AlertIssuer) {
        self.alertIssuer = alertIssuer
        self.pluginManager = pluginManager
        self.deviceDataManager = deviceDataManager

        if FeatureFlags.allowSimulators {
            mockSupports = [MockSupport(defaults: UserDefaults.appGroup!)]
        } else {
            mockSupports = []
        }
        
        availableSupports.forEach {
            addSupport($0)
        }
        
        // TODO
        //restoreState()
        
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

    func addSupport(_ support: SupportUI) {
        supports.mutate {
            $0.append(support)
            support.setAlertIssuer(alertIssuer: alertIssuer)
        }
    }

    func restoreSupport(_ support: SupportUI) {
        addSupport(support)
    }

    func removeSupport(_ support: SupportUI) {
        supports.mutate {
            $0.removeAll { $0.supportIdentifier == support.supportIdentifier }
            support.setAlertIssuer(alertIssuer: nil)
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
    }
    
    public func softwareUpdateView(guidanceColors: GuidanceColors) -> AnyView? {
        return lastHighestVersionCheckUI?.softwareUpdateView(
            guidanceColors: guidanceColors,
            bundleIdentifier: Bundle.main.bundleIdentifier!,
            currentVersion: Bundle.main.shortVersionString,
            openAppStoreHook: openAppStore)
    }
    
    // Returns the SupportUI that gave the last "highest" VersionUpdate, or `nil` if there is none
    private var lastHighestVersionCheckUI: SupportUI? {
        return supports.value.first {
            $0.supportIdentifier == identifierWithHighestVersionUpdate
        }
    }
    
    func checkVersion(completion: @escaping (VersionUpdate) -> Void) {
        let group = DispatchGroup()
        var results = [String: Result<VersionUpdate?, Error>]()
        let supports = supports.value
        supports.forEach { support in
            group.enter()
            support.checkVersion(bundleIdentifier: Bundle.main.bundleIdentifier!, currentVersion: Bundle.main.shortVersionString) { result in
                results[support.supportIdentifier] = result
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else { return }
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

extension SupportManager {
    public func openAppStore() {
        if let appStoreURLString = Bundle.main.appStoreURL,
            let appStoreURL = URL(string: appStoreURLString) {
            UIApplication.shared.open(appStoreURL)
        }
    }
}

extension SupportManager {
    var availableSupports: [SupportUI] {
        let availableSupports = pluginManager.availableSupports + deviceDataManager.availableSupports + mockSupports
        return availableSupports.sorted { $0.supportIdentifier < $1.supportIdentifier } // Provide a consistent ordering
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
}
