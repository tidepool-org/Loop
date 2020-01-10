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

    var dosingDecisionStore: DosingDecisionStore? { get }

    var glucoseStore: GlucoseStore? { get }

    var settingsStore: SettingsStore? { get }

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
        uploadExistingData(to: remoteDataService)
    }

    func restoreService(_ remoteDataService: RemoteDataService) {
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

    private func uploadExistingData(to remoteDataService: RemoteDataService) {
        if let carbStore = delegate?.carbStore {
            uploadCarbData(from: carbStore, to: remoteDataService)
        }
        if let doseStore = delegate?.doseStore {
            uploadDoseData(from: doseStore, to: remoteDataService)
        }
        if let dosingDecisionStore = delegate?.dosingDecisionStore {
            uploadDosingDecisionData(from: dosingDecisionStore, to: remoteDataService)
        }
        if let glucoseStore = delegate?.glucoseStore {
            uploadGlucoseData(from: glucoseStore, to: remoteDataService)
        }
        if let doseStore = delegate?.doseStore {
            uploadPumpEventData(from: doseStore, to: remoteDataService)
        }
        if let settingsStore = delegate?.settingsStore {
            uploadSettingsData(from: settingsStore, to: remoteDataService)
        }
    }

    private func clearQueryAnchors(for remoteDataService: RemoteDataService) {
        clearCarbQueryAnchor(for: remoteDataService)
        clearDoseQueryAnchor(for: remoteDataService)
        clearDosingDecisionQueryAnchor(for: remoteDataService)
        clearGlucoseQueryAnchor(for: remoteDataService)
        clearPumpEventQueryAnchor(for: remoteDataService)
        clearSettingsQueryAnchor(for: remoteDataService)
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

}

extension RemoteDataServicesManager {

    private var carbDataType: String { return "Carb" }

    public func carbStoreHasUpdatedCarbData(_ carbStore: CarbStore) {
        remoteDataServices.forEach { self.uploadCarbData(from: carbStore, to: $0) }
    }

    private func uploadCarbData(from carbStore: CarbStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: carbDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.carbDataType) ?? CarbStore.QueryAnchor()

            carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.carbDataLimit ?? Int.max) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying carb data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let deleted, let stored):
                    remoteDataService.uploadCarbData(deleted: deleted, stored: stored) { result in
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
        remoteDataServices.forEach { self.uploadDoseData(from: doseStore, to: $0) }
    }

    private func uploadDoseData(from doseStore: DoseStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: doseDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.doseDataType) ?? DoseStore.QueryAnchor()

            doseStore.executeDoseQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.doseDataLimit ?? Int.max) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying dose data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let data):
                    remoteDataService.uploadDoseData(data) { result in
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

    private var dosingDecisionDataType: String { return "DosingDecision" }

    public func dosingDecisionStoreHasUpdatedDosingDecisionData(_ dosingDecisionStore: DosingDecisionStore) {
        remoteDataServices.forEach { self.uploadDosingDecisionData(from: dosingDecisionStore, to: $0) }
    }

    private func uploadDosingDecisionData(from dosingDecisionStore: DosingDecisionStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: dosingDecisionDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.dosingDecisionDataType) ?? DosingDecisionStore.QueryAnchor()

            dosingDecisionStore.executeDosingDecisionQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.dosingDecisionDataLimit ?? Int.max) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying dosing decision data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let data):
                    remoteDataService.uploadDosingDecisionData(data) { result in
                        switch result {
                        case .failure(let error):
                            self.log.error("Error synchronizing dosing decision data: %{public}@", String(describing: error))
                        case .success:
                            UserDefaults.appGroup?.setQueryAnchor(for: remoteDataService, withDataType: self.dosingDecisionDataType, queryAnchor)
                        }
                        semaphore.signal()
                    }
                }
            }

            semaphore.wait()
        }
    }

    private func clearDosingDecisionQueryAnchor(for remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: dosingDecisionDataType).async {
            UserDefaults.appGroup?.deleteQueryAnchor(for: remoteDataService, withDataType: self.dosingDecisionDataType)
        }
    }

}

extension RemoteDataServicesManager {

    private var glucoseDataType: String { return "Glucose" }

    public func glucoseStoreHasUpdatedGlucoseData(_ glucoseStore: GlucoseStore) {
        remoteDataServices.forEach { self.uploadGlucoseData(from: glucoseStore, to: $0) }
    }

    private func uploadGlucoseData(from glucoseStore: GlucoseStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: glucoseDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.glucoseDataType) ?? GlucoseStore.QueryAnchor()

            glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.glucoseDataLimit ?? Int.max) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying glucose data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let data):
                    remoteDataService.uploadGlucoseData(data) { result in
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
        remoteDataServices.forEach { self.uploadPumpEventData(from: doseStore, to: $0) }
    }

    private func uploadPumpEventData(from doseStore: DoseStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: pumpEventDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.pumpEventDataType) ?? DoseStore.QueryAnchor()

            doseStore.executePumpEventQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.pumpEventDataLimit ?? Int.max) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying pump event data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let data):
                    remoteDataService.uploadPumpEventData(data) { result in
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
        remoteDataServices.forEach { self.uploadSettingsData(from: settingsStore, to: $0) }
    }

    private func uploadSettingsData(from settingsStore: SettingsStore, to remoteDataService: RemoteDataService) {
        dispatchQueue(for: remoteDataService, withDataType: settingsDataType).async {
            let semaphore = DispatchSemaphore(value: 0)
            let queryAnchor = UserDefaults.appGroup?.getQueryAnchor(for: remoteDataService, withDataType: self.settingsDataType) ?? SettingsStore.QueryAnchor()

            settingsStore.executeSettingsQuery(fromQueryAnchor: queryAnchor, limit: remoteDataService.settingsDataLimit ?? Int.max) { result in
                switch result {
                case .failure(let error):
                    self.log.error("Error querying settings data: %{public}@", String(describing: error))
                    semaphore.signal()
                case .success(let queryAnchor, let data):
                    remoteDataService.uploadSettingsData(data) { result in
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
