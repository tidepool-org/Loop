//
//  RemoteDataServicesManager.swift
//  Loop
//
//  Created by Nate Racklyeft on 6/29/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import os.log
import Foundation
import LoopKit

protocol RemoteDataServicesManagerDelegate: AnyObject {

    var carbStore: CarbStore? { get }

    var doseStore: DoseStore? { get }

    var glucoseStore: GlucoseStore? { get }

    var settingsStore: SettingsStore? { get }

    var statusStore: StatusStore? { get }

}

final class RemoteDataServicesManager {

    public typealias RawState = [String: Any]

    public weak var delegate: RemoteDataServicesManagerDelegate?

    private var lock = UnfairLock()

    private var unlockedRemoteDataServices = [RemoteDataService]()

    private var unlockedDispatchQueues = [String: DispatchQueue]()

    private let log = OSLog(category: "RemoteDataServicesManager")

    init() {}

    func addService(_ remoteDataService: RemoteDataService) {
        lock.withLock {
            unlockedRemoteDataServices.append(remoteDataService)
        }
    }

    func removeService(_ remoteDataService: RemoteDataService) {
        lock.withLock {
            unlockedRemoteDataServices.removeAll { $0.serviceIdentifier == remoteDataService.serviceIdentifier }
        }
        clearQueryAnchors(for: remoteDataService)
    }

    private var remoteDataServices: [RemoteDataService] { return lock.withLock { unlockedRemoteDataServices } }

    private func dispatchQueue(for remoteDataService: RemoteDataService, withDataType dataType: String) -> DispatchQueue {
        return lock.withLock {
            let dispatchQueueName = self.dispatchQueueName(for: remoteDataService, withDataType: dataType)

            if let dispatchQueue = self.unlockedDispatchQueues[dispatchQueueName] {
                return dispatchQueue
            }

            let dispatchQueue = DispatchQueue(label: dispatchQueueName, qos: .utility)
            self.unlockedDispatchQueues[dispatchQueueName] = dispatchQueue
            return dispatchQueue
        }
    }

    private func dispatchQueueName(for remoteDataService: RemoteDataService, withDataType dataType: String) -> String {
        return "com.loopkit.Loop.RemoteDataServicesManager.\(remoteDataService.serviceIdentifier).\(dataType)DispatchQueue"
    }

    private func clearQueryAnchors(for remoteDataService: RemoteDataService) {
        clearCarbQueryAnchor(for: remoteDataService)
        clearDoseQueryAnchor(for: remoteDataService)
        clearGlucoseQueryAnchor(for: remoteDataService)
        clearPumpEventQueryAnchor(for: remoteDataService)
        clearSettingsQueryAnchor(for: remoteDataService)
        clearStatusQueryAnchor(for: remoteDataService)
    }

}

extension RemoteDataServicesManager {

    private var carbDataType: String { return "Carb" }

    public func carbStoreHasUpdatedCarbData(_ carbStore: CarbStore) {
        remoteDataServices.forEach { self.synchronizeCarbData(from: carbStore, to: $0) }
    }

    private func synchronizeCarbData(from carbStore: CarbStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: carbDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.carbDataType) ?? CarbStore.QueryAnchor()

            carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.carbDataLimit) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying carb data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let deleted, let stored):
                    remoteDataService.synchronizeCarbData(deleted: deleted, stored: stored) { result in
                        switch result {
                        case .failure(let error):
                            self.log.error("Error synchronizing carb data: %{public}@", String(describing: error))
                        case .success:
                            UserDefaults.appGroup?.setQueryAnchor(for: remoteDataService, withDataType: self.carbDataType, queryAnchor)
                        }
                        semaphore.signal()
                    }
                }
            }

            semaphore.wait()
        }
    }

    private func clearCarbQueryAnchor(for remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: carbDataType).async {
            UserDefaults.appGroup?.deleteQueryAnchor(for: remoteDataService, withDataType: self.carbDataType)
        }
    }

}

extension RemoteDataServicesManager {

    private var doseDataType: String { return "Dose" }

    public func doseStoreHasUpdatedDoseData(_ doseStore: DoseStore) {
        remoteDataServices.forEach { self.synchronizeDoseData(from: doseStore, to: $0) }
    }

    private func synchronizeDoseData(from doseStore: DoseStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: doseDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.doseDataType) ?? DoseStore.QueryAnchor()

            doseStore.executeDoseQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.doseDataLimit) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying dose data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let data):
                    remoteDataService.synchronizeDoseData(data) { result in
                        switch result {
                        case .failure(let error):
                            self.log.error("Error synchronizing dose data: %{public}@", String(describing: error))
                        case .success:
                            UserDefaults.appGroup?.setQueryAnchor(for: remoteDataService, withDataType: self.doseDataType, queryAnchor)
                        }
                        semaphore.signal()
                    }
                }
            }

            semaphore.wait()
        }
    }

    private func clearDoseQueryAnchor(for remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: doseDataType).async {
            UserDefaults.appGroup?.deleteQueryAnchor(for: remoteDataService, withDataType: self.doseDataType)
        }
    }

}

extension RemoteDataServicesManager {

    private var glucoseDataType: String { return "Glucose" }

    public func glucoseStoreHasUpdatedGlucoseData(_ glucoseStore: GlucoseStore) {
        remoteDataServices.forEach { self.synchronizeGlucoseData(from: glucoseStore, to: $0) }
    }

    private func synchronizeGlucoseData(from glucoseStore: GlucoseStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: glucoseDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.glucoseDataType) ?? GlucoseStore.QueryAnchor()

            glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.glucoseDataLimit) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying glucose data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let data):
                    remoteDataService.synchronizeGlucoseData(data) { result in
                        switch result {
                        case .failure(let error):
                            self.log.error("Error synchronizing glucose data: %{public}@", String(describing: error))
                        case .success:
                            UserDefaults.appGroup?.setQueryAnchor(for: remoteDataService, withDataType: self.glucoseDataType, queryAnchor)
                        }
                        semaphore.signal()
                    }
                }
            }

            semaphore.wait()
        }
    }

    private func clearGlucoseQueryAnchor(for remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: glucoseDataType).async {
            UserDefaults.appGroup?.deleteQueryAnchor(for: remoteDataService, withDataType: self.glucoseDataType)
        }
    }

}

extension RemoteDataServicesManager {

    private var pumpEventDataType: String { return "PumpEvent" }

    public func doseStoreHasUpdatedPumpEventData(_ doseStore: DoseStore) {
        remoteDataServices.forEach { self.synchronizePumpEventData(from: doseStore, to: $0) }
    }

    private func synchronizePumpEventData(from doseStore: DoseStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: pumpEventDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.pumpEventDataType) ?? DoseStore.QueryAnchor()

            doseStore.executePumpEventQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.pumpEventDataLimit) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying pump event data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let data):
                    remoteDataService.synchronizePumpEventData(data) { result in
                        switch result {
                        case .failure(let error):
                            self.log.error("Error synchronizing pump event data: %{public}@", String(describing: error))
                        case .success:
                            UserDefaults.appGroup?.setQueryAnchor(for: remoteDataService, withDataType: self.pumpEventDataType, queryAnchor)
                        }
                        semaphore.signal()
                    }
                }
            }

            semaphore.wait()
        }
    }

    private func clearPumpEventQueryAnchor(for remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: pumpEventDataType).async {
            UserDefaults.appGroup?.deleteQueryAnchor(for: remoteDataService, withDataType: self.pumpEventDataType)
        }
    }

}

extension RemoteDataServicesManager {

    private var settingsDataType: String { return "Settings" }

    public func settingsStoreHasUpdatedSettingsData(_ settingsStore: SettingsStore) {
        remoteDataServices.forEach { self.synchronizeSettingsData(from: settingsStore, to: $0) }
    }

    private func synchronizeSettingsData(from settingsStore: SettingsStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: settingsDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.settingsDataType) ?? SettingsStore.QueryAnchor()

            settingsStore.executeSettingsQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.settingsDataLimit) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying settings data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let data):
                    remoteDataService.synchronizeSettingsData(data) { result in
                        switch result {
                        case .failure(let error):
                            self.log.error("Error synchronizing settings data: %{public}@", String(describing: error))
                        case .success:
                            UserDefaults.appGroup?.setQueryAnchor(for: remoteDataService, withDataType: self.settingsDataType, queryAnchor)
                        }
                        semaphore.signal()
                    }
                }
            }

            semaphore.wait()
        }
    }

    private func clearSettingsQueryAnchor(for remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: settingsDataType).async {
            UserDefaults.appGroup?.deleteQueryAnchor(for: remoteDataService, withDataType: self.settingsDataType)
        }
    }

}

extension RemoteDataServicesManager {

    private var statusDataType: String { return "Status" }

    public func statusStoreHasUpdatedStatusData(_ statusStore: StatusStore) {
        remoteDataServices.forEach { self.synchronizeStatusData(from: statusStore, to: $0) }
    }

    private func synchronizeStatusData(from statusStore: StatusStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: statusDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.statusDataType) ?? StatusStore.QueryAnchor()

            statusStore.executeStatusQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.statusDataLimit) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying status data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let data):
                    remoteDataService.synchronizeStatusData(data) { result in
                        switch result {
                        case .failure(let error):
                            self.log.error("Error synchronizing status data: %{public}@", String(describing: error))
                        case .success:
                            UserDefaults.appGroup?.setQueryAnchor(for: remoteDataService, withDataType: self.statusDataType, queryAnchor)
                        }
                        semaphore.signal()
                    }
                }
            }

            semaphore.wait()
        }
    }

    private func clearStatusQueryAnchor(for remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: statusDataType).async {
            UserDefaults.appGroup?.deleteQueryAnchor(for: remoteDataService, withDataType: self.statusDataType)
        }
    }

}

fileprivate extension UserDefaults {

    private func queryAnchorKey(for remoteDataService: RemoteDataService, withDataType dataType: String) -> String {
        return "com.loopkit.Loop.RemoteDataServicesManager.\(remoteDataService.serviceIdentifier).\(dataType)QueryAnchor"
    }

    func getQueryAnchor<T>(for remoteDataService: RemoteDataService, withDataType dataType: String) -> T? where T: RawRepresentable, T.RawValue == [String: Any] {
        let queryAnchorKeyX = queryAnchorKey(for: remoteDataService, withDataType: dataType)
        guard let rawQueryAnchor = dictionary(forKey: queryAnchorKeyX) else {
            return nil
        }
        return T.init(rawValue: rawQueryAnchor)
    }

    func setQueryAnchor<T>(for remoteDataService: RemoteDataService, withDataType dataType: String, _ queryAnchor: T) where T: RawRepresentable, T.RawValue == [String: Any] {
        set(queryAnchor.rawValue, forKey: queryAnchorKey(for: remoteDataService, withDataType: dataType))
    }

    func deleteQueryAnchor(for remoteDataService: RemoteDataService, withDataType dataType: String) {
        removeObject(forKey: queryAnchorKey(for: remoteDataService, withDataType: dataType))
    }

}
