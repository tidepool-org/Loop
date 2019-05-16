//
//  RemoteDataManager.swift
//  Loop
//
//  Created by Nate Racklyeft on 6/29/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit


protocol RemoteDataManagerDelegate: class {

    func remoteDataManagerDidUpdateServices(_ dataManager: RemoteDataManager)

}

final class RemoteDataManager: RemoteData, CarbStoreSyncDelegate {

    weak var delegate: RemoteDataManagerDelegate?

    private let servicesManager: ServicesManager

    private unowned let deviceDataManager: DeviceDataManager

    private var remoteData: [RemoteData]

    init(servicesManager: ServicesManager, deviceDataManager: DeviceDataManager) {
        self.servicesManager = servicesManager
        self.deviceDataManager = deviceDataManager

        self.remoteData = servicesManager.services.compactMap({ $0 as? RemoteData })

        servicesManager.addObserver(self)

        NotificationCenter.default.addObserver(self, selector: #selector(loopDataUpdated(_:)), name: .LoopDataUpdated, object: deviceDataManager.loopManager)
    }

    @objc func loopDataUpdated(_ note: Notification) {
        guard
            !remoteData.isEmpty,
            let rawContext = note.userInfo?[LoopDataManager.LoopUpdateContextKey] as? LoopDataManager.LoopUpdateContext.RawValue,
            let context = LoopDataManager.LoopUpdateContext(rawValue: rawContext),
            case .tempBasal = context
            else {
                return
        }

        deviceDataManager.loopManager.getLoopState { (manager, state) in
            var loopError = state.error
            let recommendedBolus: Double?

            recommendedBolus = state.recommendedBolus?.recommendation.amount

            let carbsOnBoard = state.carbsOnBoard
            let predictedGlucose = state.predictedGlucose
            let recommendedTempBasal = state.recommendedTempBasal
            let lastTempBasal = state.lastTempBasal

            manager.doseStore.insulinOnBoard(at: Date()) { (result) in
                let insulinOnBoard: InsulinValue?

                switch result {
                case .success(let value):
                    insulinOnBoard = value
                case .failure(let error):
                    insulinOnBoard = nil

                    if loopError == nil {
                        loopError = error
                    }
                }

                self.uploadLoopStatus(
                    insulinOnBoard: insulinOnBoard,
                    carbsOnBoard: carbsOnBoard,
                    predictedGlucose: predictedGlucose,
                    recommendedTempBasal: recommendedTempBasal,
                    recommendedBolus: recommendedBolus,
                    lastTempBasal: lastTempBasal,
                    loopError: loopError
                )
            }
        }
    }

    func uploadLoopStatus(insulinOnBoard: InsulinValue? = nil, carbsOnBoard: CarbValue? = nil, predictedGlucose: [GlucoseValue]? = nil, recommendedTempBasal: (recommendation: TempBasalRecommendation, date: Date)? = nil, recommendedBolus: Double? = nil, lastTempBasal: DoseEntry? = nil, lastReservoirValue: ReservoirValue? = nil, pumpManagerStatus: PumpManagerStatus? = nil, loopError: Error? = nil) {
        remoteData.forEach {
            $0.uploadLoopStatus(
                insulinOnBoard: insulinOnBoard,
                carbsOnBoard: carbsOnBoard,
                predictedGlucose: predictedGlucose,
                recommendedTempBasal: recommendedTempBasal,
                recommendedBolus: recommendedBolus,
                lastTempBasal: lastTempBasal,
                lastReservoirValue: lastReservoirValue ?? deviceDataManager.loopManager.doseStore.lastReservoirValue,
                pumpManagerStatus: pumpManagerStatus ?? deviceDataManager.pumpManagerStatus,
                loopError: loopError)
        }
    }

    func upload(pumpStatus: PumpStatus?, deviceName: String?, firmwareVersion: String?) {
        remoteData.forEach { $0.upload(pumpStatus: pumpStatus, deviceName: deviceName, firmwareVersion: firmwareVersion) }
    }


    func upload(glucoseValues values: [GlucoseValue], sensorState: SensorDisplayable?) {
        remoteData.forEach { $0.upload(glucoseValues: values, sensorState: sensorState) }
    }

    func upload(pumpEvents events: [PersistedPumpEvent], fromSource source: String, completion: @escaping (Result<[URL], Error>) -> Void) {
        // TODO: How to handle completion correctly
        if remoteData.count > 0 {
            remoteData[0].upload(pumpEvents: events, fromSource: source, completion: completion)
        }
    }

    func upload(carbEntries entries: [StoredCarbEntry], completion: @escaping (_ entries: [StoredCarbEntry]) -> Void) {
        // TODO: How to handle completion correctly
        if remoteData.count > 0 {
            remoteData[0].upload(carbEntries: entries, completion: completion)
        }
    }

    func delete(carbEntries entries: [DeletedCarbEntry], completion: @escaping (_ entries: [DeletedCarbEntry]) -> Void) {
        // TODO: How to handle completion correctly
        if remoteData.count > 0 {
            remoteData[0].delete(carbEntries: entries, completion: completion)
        }
    }

    var carbStoreSyncDelegate: CarbStoreSyncDelegate? {
        guard !remoteData.isEmpty else {
            return nil
        }
        return self
    }

    func carbStore(_ carbStore: CarbStore, hasEntriesNeedingUpload entries: [StoredCarbEntry], completion: @escaping (_ entries: [StoredCarbEntry]) -> Void) {
        upload(carbEntries: entries, completion: completion)
    }

    func carbStore(_ carbStore: CarbStore, hasDeletedEntries entries: [DeletedCarbEntry], completion: @escaping (_ entries: [DeletedCarbEntry]) -> Void) {
        delete(carbEntries: entries, completion: completion)
    }

}

extension RemoteDataManager: ServicesManagerObserver {

    func servicesManagerDidUpdate(services: [Service]) {
        remoteData = servicesManager.services.compactMap({ $0 as? RemoteData })
        delegate?.remoteDataManagerDidUpdateServices(self)
    }

}
