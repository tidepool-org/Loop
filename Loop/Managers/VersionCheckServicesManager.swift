//
//  VersionCheckServicesManager.swift
//  Loop
//
//  Created by Rick Pasetto on 9/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import simd

public final class VersionCheckServicesManager {

    private lazy var log = DiagnosticLog(category: "VersionCheckServicesManager")
    private lazy var dispatchQueue = DispatchQueue(label: "com.loopkit.Loop.VersionCheckServicesManager")

    private var versionCheckServices = Locked<[VersionCheckService]>([])
    
    init() {}

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
}
