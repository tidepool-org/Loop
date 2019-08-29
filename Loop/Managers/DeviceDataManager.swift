//
//  DeviceDataManager.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/30/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import HealthKit
import LoopKit
import LoopKitUI
import LoopCore
import LoopTestingKit
import UserNotifications

final class DeviceDataManager {

    private let queue = DispatchQueue(label: "com.loopkit.DeviceManagerQueue", qos: .utility)

    let servicesManager: ServicesManager

    private let log = DiagnosticLog(category: "DeviceDataManager")

    let analyticsManager: AnalyticsManager

    /// Remember the launch date of the app for diagnostic reporting
    private let launchDate = Date()

    /// Manages authentication for remote services
    var remoteDataManager: RemoteDataManager!

    /// The last error recorded by a device manager
    /// Should be accessed only on the main queue
    private(set) var lastError: (date: Date, error: Error)?

    // MARK: - CGM

    var cgmManager: CGMManager? {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            setupCGM()
            UserDefaults.appGroup?.cgmManager = cgmManager
        }
    }

    // MARK: - Pump

    var pumpManager: PumpManagerUI? {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))

            // If the current CGMManager is a PumpManager, we clear it out.
            if cgmManager is PumpManagerUI {
                cgmManager = nil
            }

            setupPump()

            NotificationCenter.default.post(name: .PumpManagerChanged, object: self, userInfo: nil)

            UserDefaults.appGroup?.pumpManager = pumpManager
        }
    }

    private(set) var pumpManagerHUDProvider: HUDProvider?

    // MARK: - WatchKit

    private var watchManager: WatchDataManager!

    // MARK: - Status Extension

    private var statusExtensionManager: StatusExtensionDataManager!

    // MARK: - Initialization

    private(set) var loopManager: LoopDataManager!

    init(servicesManager: ServicesManager, analyticsManager: AnalyticsManager) {
        self.servicesManager = servicesManager
        self.analyticsManager = analyticsManager

        pumpManager = UserDefaults.appGroup?.pumpManager as? PumpManagerUI

        if let cgmManager = UserDefaults.appGroup?.cgmManager {
            self.cgmManager = cgmManager
        } else if UserDefaults.appGroup?.isCGMManagerValidPumpManager == true {
            self.cgmManager = pumpManager as? CGMManager
        }

        remoteDataManager = RemoteDataManager(servicesManager: servicesManager, deviceDataManager: self)
        statusExtensionManager = StatusExtensionDataManager(deviceDataManager: self)
        loopManager = LoopDataManager(
            lastLoopCompleted: statusExtensionManager.context?.lastLoopCompleted,
            lastTempBasal: statusExtensionManager.context?.netBasal?.tempBasal,
            analyticsManager: analyticsManager
        )
        watchManager = WatchDataManager(deviceManager: self, analyticsManager: analyticsManager)

        loopManager.delegate = self
        loopManager.carbStore.syncDelegate = remoteDataManager
        loopManager.doseStore.delegate = self

        setupPump()
        setupCGM()
    }
}

private extension DeviceDataManager {
    func setupCGM() {
        dispatchPrecondition(condition: .onQueue(.main))

        cgmManager?.cgmManagerDelegate = self
        cgmManager?.delegateQueue = queue
        loopManager.glucoseStore.managedDataInterval = cgmManager?.managedDataInterval

        updatePumpManagerBLEHeartbeatPreference()
    }

    func setupPump() {
        dispatchPrecondition(condition: .onQueue(.main))

        pumpManager?.pumpManagerDelegate = self
        pumpManager?.delegateQueue = queue

        loopManager.doseStore.device = pumpManager?.status.device
        pumpManagerHUDProvider = pumpManager?.hudProvider()

        // Proliferate PumpModel preferences to DoseStore
        if let pumpRecordsBasalProfileStartEvents = pumpManager?.pumpRecordsBasalProfileStartEvents {
            loopManager?.doseStore.pumpRecordsBasalProfileStartEvents = pumpRecordsBasalProfileStartEvents
        }
    }

    func setLastError(error: Error) {
        DispatchQueue.main.async {
            self.lastError = (date: Date(), error: error)
        }
    }
}

// MARK: - Client API
extension DeviceDataManager {
    func enactBolus(units: Double, at startDate: Date = Date(), completion: @escaping (_ error: Error?) -> Void) {
        guard let pumpManager = pumpManager else {
            completion(LoopError.configurationError(.pumpManager))
            return
        }

        pumpManager.enactBolus(units: units, at: startDate, willRequest: { (dose) in
            self.loopManager.addRequestedBolus(dose, completion: nil)
        }) { (result) in
            switch result {
            case .failure(let error):
                self.log.error("%{public}@", String(reflecting: error))
                NotificationManager.sendBolusFailureNotification(for: error, units: units, at: startDate)
                completion(error)
            case .success(let dose):
                self.loopManager.addConfirmedBolus(dose) {
                    completion(nil)
                }
            }
        }
    }

    var pumpManagerStatus: PumpManagerStatus? {
        return pumpManager?.status
    }

    var sensorState: SensorDisplayable? {
        return cgmManager?.sensorState
    }

    func updatePumpManagerBLEHeartbeatPreference() {
        pumpManager?.setMustProvideBLEHeartbeat(pumpManagerMustProvideBLEHeartbeat)
    }
}

// MARK: - DeviceManagerDelegate
extension DeviceDataManager: DeviceManagerDelegate {
    func scheduleNotification(for manager: DeviceManager,
                              identifier: String,
                              content: UNNotificationContent,
                              trigger: UNNotificationTrigger?) {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func clearNotification(for manager: DeviceManager, identifier: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

// MARK: - CGMManagerDelegate
extension DeviceDataManager: CGMManagerDelegate {
    func cgmManagerWantsDeletion(_ manager: CGMManager) {
        dispatchPrecondition(condition: .onQueue(queue))
        DispatchQueue.main.async {
            self.cgmManager = nil
        }
    }

    func cgmManager(_ manager: CGMManager, didUpdateWith result: CGMResult) {
        dispatchPrecondition(condition: .onQueue(queue))
        switch result {
        case .newData(let values):
            log.default("CGMManager:%{public}@ did update with %d values", String(describing: type(of: manager)), values.count)

            loopManager.addGlucose(values) { result in
                if manager.shouldSyncToRemoteService {
                    switch result {
                    case .success:
                        self.remoteDataManager.synchronizeRemoteData()
                    case .failure:
                        break
                    }
                }

                self.pumpManager?.assertCurrentPumpData()
            }
        case .noData:
            log.default("CGMManager:%{public}@ did update with no data", String(describing: type(of: manager)))

            pumpManager?.assertCurrentPumpData()
        case .error(let error):
            log.default("CGMManager:%{public}@ did update with error: %{public}@", String(describing: type(of: manager)), String(reflecting: error))

            self.setLastError(error: error)
            pumpManager?.assertCurrentPumpData()
        }

        updatePumpManagerBLEHeartbeatPreference()
    }

    func startDateToFilterNewData(for manager: CGMManager) -> Date? {
        dispatchPrecondition(condition: .onQueue(queue))
        return loopManager.glucoseStore.latestGlucose?.startDate
    }

    func cgmManagerDidUpdateState(_ manager: CGMManager) {
        dispatchPrecondition(condition: .onQueue(queue))
        UserDefaults.appGroup?.cgmManager = manager
    }
}


// MARK: - PumpManagerDelegate
extension DeviceDataManager: PumpManagerDelegate {
    func pumpManager(_ pumpManager: PumpManager, didAdjustPumpClockBy adjustment: TimeInterval) {
        dispatchPrecondition(condition: .onQueue(queue))
        log.default("PumpManager:%{public}@ did adjust pump block by %fs", String(describing: type(of: pumpManager)), adjustment)

        analyticsManager.pumpTimeDidDrift(adjustment)
    }

    func pumpManagerDidUpdateState(_ pumpManager: PumpManager) {
        dispatchPrecondition(condition: .onQueue(queue))
        log.default("PumpManager:%{public}@ did update state", String(describing: type(of: pumpManager)))

        UserDefaults.appGroup?.pumpManager = pumpManager
    }

    func pumpManagerBLEHeartbeatDidFire(_ pumpManager: PumpManager) {
        dispatchPrecondition(condition: .onQueue(queue))
        log.default("PumpManager:%{public}@ did fire BLE heartbeat", String(describing: type(of: pumpManager)))

        cgmManager?.fetchNewDataIfNeeded { (result) in
            if case .newData = result {
                self.analyticsManager.didFetchNewCGMData()
            }

            if let manager = self.cgmManager {
                self.queue.async {
                    self.cgmManager(manager, didUpdateWith: result)
                }
            }
        }
    }

    func pumpManagerMustProvideBLEHeartbeat(_ pumpManager: PumpManager) -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))
        return pumpManagerMustProvideBLEHeartbeat
    }

    private var pumpManagerMustProvideBLEHeartbeat: Bool {
        /// Controls the management of the RileyLink timer tick, which is a reliably-changing BLE
        /// characteristic which can cause the app to wake. For most users, the G5 Transmitter and
        /// G4 Receiver are reliable as hearbeats, but users who find their resources extremely constrained
        /// due to greedy apps or older devices may choose to always enable the timer by always setting `true`
        return !(cgmManager?.providesBLEHeartbeat == true)
    }

    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        dispatchPrecondition(condition: .onQueue(queue))
        log.default("PumpManager:%{public}@ did update status: %{public}@", String(describing: type(of: pumpManager)), String(describing: status))

        loopManager.doseStore.device = status.device

        if let newBatteryValue = status.pumpBatteryChargeRemaining {
            if newBatteryValue == 0 {
                NotificationManager.sendPumpBatteryLowNotification()
            } else {
                NotificationManager.clearPumpBatteryLowNotification()
            }

            if let oldBatteryValue = oldStatus.pumpBatteryChargeRemaining, newBatteryValue - oldBatteryValue >= loopManager.settings.batteryReplacementDetectionThreshold {
                analyticsManager.pumpBatteryWasReplaced()
            }
        }

        // Update the pump-schedule based settings
        loopManager.setScheduleTimeZone(status.timeZone)
    }

    func pumpManagerWillDeactivate(_ pumpManager: PumpManager) {
        dispatchPrecondition(condition: .onQueue(queue))

        log.default("PumpManager:%{public}@ will deactivate", String(describing: type(of: pumpManager)))

        loopManager.doseStore.resetPumpData()
        DispatchQueue.main.async {
            self.pumpManager = nil
        }
    }

    func pumpManager(_ pumpManager: PumpManager, didUpdatePumpRecordsBasalProfileStartEvents pumpRecordsBasalProfileStartEvents: Bool) {
        dispatchPrecondition(condition: .onQueue(queue))
        log.default("PumpManager:%{public}@ did update pumpRecordsBasalProfileStartEvents to %{public}@", String(describing: type(of: pumpManager)), String(describing: pumpRecordsBasalProfileStartEvents))

        loopManager.doseStore.pumpRecordsBasalProfileStartEvents = pumpRecordsBasalProfileStartEvents
    }

    func pumpManager(_ pumpManager: PumpManager, didError error: PumpManagerError) {
        dispatchPrecondition(condition: .onQueue(queue))
        log.error("PumpManager:%{public}@ did error: %{public}@", String(describing: type(of: pumpManager)), String(reflecting: error))

        setLastError(error: error)
        remoteDataManager.uploadLoopStatus(loopError: error)
    }

    func pumpManager(_ pumpManager: PumpManager, didReadPumpEvents events: [NewPumpEvent], completion: @escaping (_ error: Error?) -> Void) {
        dispatchPrecondition(condition: .onQueue(queue))
        log.default("PumpManager:%{public}@ did read pump events", String(describing: type(of: pumpManager)))

        loopManager.addPumpEvents(events) { (error) in
            if let error = error {
                self.log.error("Failed to addPumpEvents to DoseStore: %{public}@", String(reflecting: error))
            }

            completion(error)
        }
    }

    func pumpManager(_ pumpManager: PumpManager, didReadReservoirValue units: Double, at date: Date, completion: @escaping (_ result: PumpManagerResult<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool)>) -> Void) {
        dispatchPrecondition(condition: .onQueue(queue))
        log.default("PumpManager:%{public}@ did read reservoir value", String(describing: type(of: pumpManager)))

        loopManager.addReservoirValue(units, at: date) { (result) in
            switch result {
            case .failure(let error):
                self.log.error("Failed to addReservoirValue: %{public}@", String(reflecting: error))
                completion(.failure(error))
            case .success(let (newValue, lastValue, areStoredValuesContinuous)):
                completion(.success((newValue: newValue, lastValue: lastValue, areStoredValuesContinuous: areStoredValuesContinuous)))

                // Send notifications for low reservoir if necessary
                if let previousVolume = lastValue?.unitVolume {
                    guard newValue.unitVolume > 0 else {
                        NotificationManager.sendPumpReservoirEmptyNotification()
                        return
                    }

                    let warningThresholds: [Double] = [10, 20, 30]

                    for threshold in warningThresholds {
                        if newValue.unitVolume <= threshold && previousVolume > threshold {
                            NotificationManager.sendPumpReservoirLowNotificationForAmount(newValue.unitVolume, andTimeRemaining: nil)
                            break
                        }
                    }

                    if newValue.unitVolume > previousVolume + 1 {
                        self.analyticsManager.reservoirWasRewound()

                        NotificationManager.clearPumpReservoirNotification()
                    }
                }
            }
        }
    }
    
    func pumpManagerRecommendsLoop(_ pumpManager: PumpManager) {
        dispatchPrecondition(condition: .onQueue(queue))
        log.default("PumpManager:%{public}@ recommends loop", String(describing: type(of: pumpManager)))
        loopManager.loop()
    }

    func startDateToFilterNewPumpEvents(for manager: PumpManager) -> Date {
        dispatchPrecondition(condition: .onQueue(queue))
        return loopManager.doseStore.pumpEventQueryAfterDate
    }
}

// MARK: - DoseStoreDelegate
extension DeviceDataManager: DoseStoreDelegate {
    func doseStore(_ doseStore: DoseStore,
        hasEventsNeedingUpload pumpEvents: [PersistedPumpEvent],
        completion completionHandler: @escaping (_ uploadedObjectIDURLs: [URL]) -> Void
    ) {
        remoteDataManager.upload(pumpEvents: pumpEvents, fromSource: "loop://\(UIDevice.current.name)") { (result) in
            switch result {
            case .success(let objects):
                completionHandler(objects)
            case .failure(let error):
                self.log.error("%{public}@", String(reflecting: error))
                completionHandler([])
            }
        }
    }
}

// MARK: - TestingPumpManager
extension DeviceDataManager {
    func deleteTestingPumpData() {
        assertingDebugOnly {
            guard let testingPumpManager = pumpManager as? TestingPumpManager else {
                assertionFailure("\(#function) should be invoked only when a testing pump manager is in use")
                return
            }
            let devicePredicate = HKQuery.predicateForObjects(from: [testingPumpManager.testingDevice])

            // DoseStore.deleteAllPumpEvents first syncs the events to the health store,
            // so HKHealthStore.deleteObjects catches any that were still in the cache.
            let doseStore = loopManager.doseStore
            let healthStore = doseStore.insulinDeliveryStore.healthStore
            doseStore.deleteAllPumpEvents { doseStoreError in
                if doseStoreError != nil {
                    healthStore.deleteObjects(of: doseStore.sampleType!, predicate: devicePredicate) { success, deletedObjectCount, error in
                        // errors are already logged through the store, so we'll ignore them here
                    }
                }
            }
        }
    }

    func deleteTestingCGMData() {
        assertingDebugOnly {
            guard let testingCGMManager = cgmManager as? TestingCGMManager else {
                assertionFailure("\(#function) should be invoked only when a testing CGM manager is in use")
                return
            }
            let predicate = HKQuery.predicateForObjects(from: [testingCGMManager.testingDevice])
            loopManager.glucoseStore.purgeGlucoseSamples(matchingCachePredicate: nil, healthKitPredicate: predicate) { success, count, error in
                // result already logged through the store, so ignore the error here
            }
        }
    }
}

// MARK: - LoopDataManagerDelegate
extension DeviceDataManager: LoopDataManagerDelegate {
    func loopDataManager(_ manager: LoopDataManager, roundBasalRate unitsPerHour: Double) -> Double {
        guard let pumpManager = pumpManager else {
            return unitsPerHour
        }
        
        return pumpManager.roundToSupportedBasalRate(unitsPerHour: unitsPerHour)
    }

    func loopDataManager(_ manager: LoopDataManager, roundBolusVolume units: Double) -> Double {
        guard let pumpManager = pumpManager else {
            return units
        }

        return pumpManager.roundToSupportedBolusVolume(units: units)
    }

    func loopDataManager(
        _ manager: LoopDataManager,
        didRecommendBasalChange basal: (recommendation: TempBasalRecommendation, date: Date),
        completion: @escaping (_ result: Result<DoseEntry>) -> Void
    ) {
        guard let pumpManager = pumpManager else {
            completion(.failure(LoopError.configurationError(.pumpManager)))
            return
        }

        log.default("LoopManager did recommend basal change")

        pumpManager.enactTempBasal(
            unitsPerHour: basal.recommendation.unitsPerHour,
            for: basal.recommendation.duration,
            completion: { result in
                switch result {
                case .success(let doseEntry):
                    completion(.success(doseEntry))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
}


// MARK: - CustomDebugStringConvertible
extension DeviceDataManager: CustomDebugStringConvertible {
    var debugDescription: String {
        return [
            Bundle.main.localizedNameAndVersion,
            "",
            "## DeviceDataManager",
            "* launchDate: \(launchDate)",
            "* lastError: \(String(describing: lastError))",
            "",
            cgmManager != nil ? String(reflecting: cgmManager!) : "cgmManager: nil",
            "",
            pumpManager != nil ? String(reflecting: pumpManager!) : "pumpManager: nil",
            "",
            String(reflecting: watchManager!),
            "",
            String(reflecting: statusExtensionManager!),
        ].joined(separator: "\n")
    }
}

extension Notification.Name {
    static let PumpManagerChanged = Notification.Name(rawValue:  "com.loopKit.notification.PumpManagerChanged")
}

