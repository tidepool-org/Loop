//
//  RemoteDataManager.swift
//  Loop
//
//  Created by Nate Racklyeft on 6/29/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit


final class RemoteDataManager: CarbStoreSyncDelegate {

    private unowned let deviceDataManager: DeviceDataManager

    private var remoteData: [RemoteData]!

    private let log = DiagnosticLog(category: "RemoteDataManager")

    init(servicesManager: ServicesManager, deviceDataManager: DeviceDataManager) {
        self.deviceDataManager = deviceDataManager
        self.remoteData = filter(services: servicesManager.services)

        servicesManager.addObserver(self)

        NotificationCenter.default.addObserver(self, selector: #selector(loopDataUpdated(_:)), name: .LoopDataUpdated, object: deviceDataManager.loopManager)
    }

    private func filter(services: [Service]) -> [RemoteData] {
        return services.compactMap({ (service) in
            guard var remoteData = service as? RemoteData else {
                return nil
            }
            remoteData.remoteDataDelegate = self
            return remoteData
        })
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

    func upload(pumpEvents events: [PersistedPumpEvent], fromSource source: String, completion: @escaping (Result<[URL], Error>) -> Void) {
        // TODO: How to handle completion correctly
        if remoteData.count > 0 {
            remoteData[0].upload(pumpEvents: events, fromSource: source, completion: completion)
        }
    }

    func synchronizeRemoteData() {
        remoteData.forEach { self.synchronize(remoteData: $0) }
    }

    private func synchronize(remoteData: RemoteData) {
        remoteData.synchronizeRemoteData { result in
            switch result {
            case .failure(let error):
                self.log.error("Failure: %{public}@", String(reflecting: error))
            case .success(let uploaded):
                self.log.debug("Success: %d", uploaded)
            }
        }
    }

}


extension RemoteDataManager: ServicesManagerObserver {

    func servicesManagerDidUpdate(services: [Service]) {
        remoteData = filter(services: services)
    }

}


extension RemoteDataManager: RemoteDataDelegate {

    public var carbRemoteDataQueryDelegate: CarbRemoteDataQueryDelegate? {
        return deviceDataManager.loopManager?.carbStore
    }

    public var glucoseRemoteDataQueryDelegate: GlucoseRemoteDataQueryDelegate? {
        return deviceDataManager.loopManager?.glucoseStore
    }

}
