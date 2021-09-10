//
//  VersionCheckServicesManager.swift
//  Loop
//
//  Created by Rick Pasetto on 9/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

final class VersionCheckServicesManager {

    private lazy var log = DiagnosticLog(category: "VersionCheckServicesManager")

    private lazy var dispatchQueue = DispatchQueue(label: "com.loopkit.Loop.VersionCheckServicesManager")
    
    private var versionCheckServices = [VersionCheckService]()

    init() {}

    func addService(_ versionCheckService: VersionCheckService) {
        versionCheckServices.append(versionCheckService)
    }

    func restoreService(_ versionCheckService: VersionCheckService) {
        versionCheckServices.append(versionCheckService)
    }

    func removeService(_ versionCheckService: VersionCheckService) {
        versionCheckServices.removeAll { $0.serviceIdentifier == versionCheckService.serviceIdentifier }
    }

    func checkVersion(currentVersion: String) -> VersionUpdate {
        let semaphore = DispatchSemaphore(value: 0)
        var results = [String: Result<VersionUpdate, Error>]()
        versionCheckServices.forEach { versionCheckService in
            dispatchQueue.async {
                versionCheckService.checkVersion(currentVersion: currentVersion) { result in
                    self.dispatchQueue.async {
                        results[versionCheckService.serviceIdentifier] = result
                        semaphore.signal()
                    }
                }
            }
            semaphore.wait()
        }
        
        var aggregatedVersionUpdate = VersionUpdate.noneNeeded
        results.forEach { key, value in
            switch value {
            case .failure(let error):
                self.log.error("Error from version check service %{public}@: %{public}@", key, error.localizedDescription)
            case .success(let versionUpdate):
                if versionUpdate > aggregatedVersionUpdate {
                    aggregatedVersionUpdate = versionUpdate
                }
            }
        }
        return aggregatedVersionUpdate
    }
    
}
