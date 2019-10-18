//
//  RemoteDataServicesManager.swift
//  Loop
//
//  Created by Nate Racklyeft on 6/29/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit

final class RemoteDataServicesManager: CarbStoreSyncDelegate {

    private unowned let deviceDataManager: DeviceDataManager

    private var remoteDataServices = [RemoteDataService]()

    private let log = DiagnosticLog(category: "RemoteDataServicesManager")

    init(deviceDataManager: DeviceDataManager) {
        self.deviceDataManager = deviceDataManager
    }

    func addService(_ remoteDataService: RemoteDataService) {
        remoteDataServices.append(remoteDataService)
    }

    func removeService(_ remoteDataService: RemoteDataService) {
        remoteDataServices.removeAll { $0.serviceIdentifier == remoteDataService.serviceIdentifier }
    }

    func initiateRemoteDataSynchronization() {
        remoteDataServices.forEach { self.synchronizeRemoteDataService($0) }
    }

    func synchronizeRemoteDataService(_ remoteDataService: RemoteDataService) {
        remoteDataService.synchronizeRemoteData { result in
            switch result {
            case .failure(let error):
                self.log.error("Failure: %{public}@", String(reflecting: error))    // TODO: Notify the user somehow!
            case .success(let uploaded):
                self.log.debug("Success: %d", uploaded)
            }
        }
    }

}

extension RemoteDataServicesManager: RemoteDataServiceDelegate {

    var statusRemoteDataQueryDelegate: StatusRemoteDataQueryDelegate? { return deviceDataManager.loopManager!.statusStore }

    var settingsRemoteDataQueryDelegate: SettingsRemoteDataQueryDelegate? { return deviceDataManager.loopManager!.settingsStore }

    var glucoseRemoteDataQueryDelegate: GlucoseRemoteDataQueryDelegate? { return deviceDataManager.loopManager!.glucoseStore }

    var doseRemoteDataQueryDelegate: DoseRemoteDataQueryDelegate? { return deviceDataManager.loopManager!.doseStore }

    var carbRemoteDataQueryDelegate: CarbRemoteDataQueryDelegate? { return deviceDataManager.loopManager!.carbStore }

}
