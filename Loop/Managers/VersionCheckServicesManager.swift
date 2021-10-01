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

final class VersionCheckServicesManager {

    private lazy var log = DiagnosticLog(category: "VersionCheckServicesManager")
    
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
    
    @available(iOS, deprecated: 15.0.0)
    /// This version of `checkVersion` blocks the caller until it returns.
    /// May deadlock if one of the services' `checkVersion` pops back to whatever queue called this (e.g. DispatchQueue.main)!
    func checkVersion(currentVersion: String) -> VersionUpdate {
        let dispatchQueue = DispatchQueue(label: "com.loopkit.Loop.VersionCheckServicesManager")
        let semaphore = DispatchSemaphore(value: 0)
        var results = [String: Result<VersionUpdate?, Error>]()
        let services = versionCheckServices.value
        services.forEach { versionCheckService in
            dispatchQueue.async {
                versionCheckService.checkVersion(bundleIdentifier: Bundle.main.bundleIdentifier!, currentVersion: currentVersion) { result in
                    dispatchQueue.async {
                        results[versionCheckService.serviceIdentifier] = result
                        semaphore.signal()
                    }
                }
            }
            semaphore.wait()
        }
        return aggregate(results: results)
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
