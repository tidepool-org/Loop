//
//  ServicesManager.swift
//  Loop
//
//  Created by Darin Krauss on 5/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log
import Foundation
import LoopCore
import LoopKit
import LoopKitUI

class ServicesManager {

    private unowned let pluginManager: PluginManager

    private unowned let deviceDataManager: DeviceDataManager

    private var services = [Service]()

    private let servicesLock = UnfairLock()

    private var lastSettingsUpdate: Date = .distantPast

    private let log = DiagnosticLog(category: "ServicesManager")

    init(pluginManager: PluginManager, deviceDataManager: DeviceDataManager) {
        self.pluginManager = pluginManager
        self.deviceDataManager = deviceDataManager

        restoreState()

        NotificationCenter.default.addObserver(self, selector: #selector(loopCompleted(_:)), name: .LoopCompleted, object: deviceDataManager.loopManager)
        NotificationCenter.default.addObserver(self, selector: #selector(loopDataUpdated(_:)), name: .LoopDataUpdated, object: deviceDataManager.loopManager)
    }

    public var availableServices: [AvailableService] {
        return pluginManager.availableServices + availableStaticServices
    }

    func serviceUITypeByIdentifier(_ identifier: String) -> ServiceUI.Type? {
        return pluginManager.getServiceTypeByIdentifier(identifier) ?? staticServicesByIdentifier[identifier] as? ServiceUI.Type
    }

    private func serviceTypeFromRawValue(_ rawValue: Service.RawStateValue) -> Service.Type? {
        guard let identifier = rawValue["serviceIdentifier"] as? String else {
            return nil
        }

        return serviceUITypeByIdentifier(identifier)
    }

    private func serviceFromRawValue(_ rawValue: Service.RawStateValue) -> Service? {
        guard let serviceType = serviceTypeFromRawValue(rawValue),
            let rawState = rawValue["state"] as? Service.RawStateValue else {
            return nil
        }

        return serviceType.init(rawState: rawState)
    }

    public var activeServices: [Service] {
        return servicesLock.withLock { services }
    }

    public func addActiveService(_ service: Service) {
        servicesLock.withLock {
            service.serviceDelegate = self
            services.append(service)
            saveState()
        }
    }

    public func updateActiveService(_ service: Service) {
        servicesLock.withLock {
            saveState()
        }
    }

    public func removeActiveService(_ service: Service) {
        servicesLock.withLock {
            services.removeAll { $0.serviceIdentifier == service.serviceIdentifier }
            service.serviceDelegate = nil
            saveState()
        }
    }

    private func saveState() {
        UserDefaults.appGroup?.servicesState = services.compactMap { $0.rawValue }
    }

    private func restoreState() {
        services = UserDefaults.appGroup?.servicesState.compactMap { rawValue in
            let service = serviceFromRawValue(rawValue)
            service?.serviceDelegate = self
            return service
        } ?? []
    }

}

extension ServicesManager: ServiceDelegate {

    func serviceDidUpdateState(_ service: Service) {
        saveState()
    }

}

/// AnalyticsService support
extension ServicesManager {

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any]?) {
        logEvent("App Launch")
    }

    // MARK: - Screens

    func didDisplayBolusScreen() {
        logEvent("Bolus Screen")
    }

    func didDisplaySettingsScreen() {
        logEvent("Settings Screen")
    }

    func didDisplayStatusScreen() {
        logEvent("Status Screen")
    }

    // MARK: - Config Events

    func transmitterTimeDidDrift(_ drift: TimeInterval) {
        logEvent("Transmitter time change", withProperties: ["value" : drift], outOfSession: true)
    }

    func pumpTimeDidDrift(_ drift: TimeInterval) {
        logEvent("Pump time change", withProperties: ["value": drift], outOfSession: true)
    }

    func pumpTimeZoneDidChange() {
        logEvent("Pump time zone change", outOfSession: true)
    }

    func pumpBatteryWasReplaced() {
        logEvent("Pump battery replacement", outOfSession: true)
    }

    func reservoirWasRewound() {
        logEvent("Pump reservoir rewind", outOfSession: true)
    }

    func didChangeBasalRateSchedule() {
        logEvent("Basal rate change")
    }

    func didChangeCarbRatioSchedule() {
        logEvent("Carb ratio change")
    }

    func didChangeInsulinModel() {
        logEvent("Insulin model change")
    }

    func didChangeInsulinSensitivitySchedule() {
        logEvent("Insulin sensitivity change")
    }

    func didChangeLoopSettings(from oldValue: LoopSettings, to newValue: LoopSettings) {
        if newValue.maximumBasalRatePerHour != oldValue.maximumBasalRatePerHour {
            logEvent("Maximum basal rate change")
        }

        if newValue.maximumBolus != oldValue.maximumBolus {
            logEvent("Maximum bolus change")
        }

        if newValue.suspendThreshold != oldValue.suspendThreshold {
            logEvent("Minimum BG Guard change")
        }

        if newValue.dosingEnabled != oldValue.dosingEnabled {
            logEvent("Closed loop enabled change")
        }

        if newValue.retrospectiveCorrectionEnabled != oldValue.retrospectiveCorrectionEnabled {
            logEvent("Retrospective correction enabled change")
        }

        if newValue.glucoseTargetRangeSchedule != oldValue.glucoseTargetRangeSchedule {
            if newValue.glucoseTargetRangeSchedule?.timeZone != oldValue.glucoseTargetRangeSchedule?.timeZone {
                self.pumpTimeZoneDidChange()
            } else if newValue.scheduleOverride != oldValue.scheduleOverride {
                logEvent("Temporary schedule override change", outOfSession: true)
            } else {
                logEvent("Glucose target range change")
            }
        }
    }

    // MARK: - Loop Events

    func didAddCarbsFromWatch() {
        logEvent("Carb entry created", withProperties: ["source" : "Watch"], outOfSession: true)
    }

    func didRetryBolus() {
        logEvent("Bolus Retry", outOfSession: true)
    }

    func didSetBolusFromWatch(_ units: Double) {
        logEvent("Bolus set", withProperties: ["source" : "Watch"], outOfSession: true)
    }

    func didFetchNewCGMData() {
        logEvent("CGM Fetch", outOfSession: true)
    }

    func loopDidSucceed() {
        logEvent("Loop success", outOfSession: true)
    }

    func loopDidError() {
        logEvent("Loop error", outOfSession: true)
    }

    private func logEvent(_ name: String, withProperties properties: [AnyHashable: Any]? = nil, outOfSession: Bool = false) {
        log.debug("%{public}@ %{public}@", name, String(describing: properties))
        
        analyticsServices.forEach { $0.recordAnalyticsEvent(name, withProperties: properties, outOfSession: outOfSession) }
    }

    private var analyticsServices: [AnalyticsService] { services.compactMap { $0 as? AnalyticsService } }

}

/// LoggingService support
extension ServicesManager: LoggingService {

    func log(_ message: StaticString, subsystem: String, category: String, type: OSLogType, _ args: [CVarArg]) {
        loggingServices.forEach { $0.log(message, subsystem: subsystem, category: category, type: type, args) }
    }

    private var loggingServices: [LoggingService] { services.compactMap { $0 as? LoggingService } }

}

/// RemoteDataService support
extension ServicesManager: CarbStoreSyncDelegate {

    @objc func loopDataUpdated(_ note: Notification) {
        guard
            !remoteDataServices.isEmpty,
            let rawContext = note.userInfo?[LoopDataManager.LoopUpdateContextKey] as? LoopDataManager.LoopUpdateContext.RawValue,
            let context = LoopDataManager.LoopUpdateContext(rawValue: rawContext),
            case .preferences = context
            else {
                return
        }

        lastSettingsUpdate = Date()

        uploadSettings()
    }

    private func uploadSettings() {
        guard !remoteDataServices.isEmpty else {
            return
        }

        guard let settings = UserDefaults.appGroup?.loopSettings else {
            log.default("Not uploading due to incomplete configuration")
            return
        }

        remoteDataServices.forEach { $0.uploadSettings(settings, lastUpdated: lastSettingsUpdate) }
    }

    @objc func loopCompleted(_ note: Notification) {
        guard !remoteDataServices.isEmpty else {
            return
        }

        deviceDataManager.loopManager.getLoopState { (manager, state) in
            var loopError = state.error
            let recommendedBolus: Double?

            recommendedBolus = state.recommendedBolus?.recommendation.amount

            let carbsOnBoard = state.carbsOnBoard
            let predictedGlucose = state.predictedGlucose
            let recommendedTempBasal = state.recommendedTempBasal

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
                    loopError: loopError
                )

                self.uploadSettings()
            }
        }
    }

    func uploadLoopStatus(
        insulinOnBoard: InsulinValue? = nil,
        carbsOnBoard: CarbValue? = nil,
        predictedGlucose: [GlucoseValue]? = nil,
        recommendedTempBasal: (recommendation: TempBasalRecommendation, date: Date)? = nil,
        recommendedBolus: Double? = nil,
        lastReservoirValue: ReservoirValue? = nil,
        pumpManagerStatus: PumpManagerStatus? = nil,
        glucoseTargetRangeSchedule: GlucoseRangeSchedule? = nil,
        scheduleOverride: TemporaryScheduleOverride? = nil,
        glucoseTargetRangeScheduleApplyingOverrideIfActive: GlucoseRangeSchedule? = nil,
        loopError: Error? = nil)
    {
        remoteDataServices.forEach {
            $0.uploadLoopStatus(
                insulinOnBoard: insulinOnBoard,
                carbsOnBoard: carbsOnBoard,
                predictedGlucose: predictedGlucose,
                recommendedTempBasal: recommendedTempBasal,
                recommendedBolus: recommendedBolus,
                lastReservoirValue: lastReservoirValue ?? deviceDataManager.loopManager.doseStore.lastReservoirValue,
                pumpManagerStatus: pumpManagerStatus ?? deviceDataManager.pumpManagerStatus,
                glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
                scheduleOverride: scheduleOverride,
                glucoseTargetRangeScheduleApplyingOverrideIfActive: glucoseTargetRangeScheduleApplyingOverrideIfActive,
                loopError: loopError)
        }
    }

    func upload(glucoseValues values: [GlucoseValue], sensorState: SensorDisplayable?) {
        remoteDataServices.forEach { $0.upload(glucoseValues: values, sensorState: sensorState) }
    }

    func upload(pumpEvents events: [PersistedPumpEvent], fromSource source: String, completion: @escaping (Swift.Result<[URL], Error>) -> Void) {
        // TODO: How to handle completion correctly
        if !remoteDataServices.isEmpty {
            remoteDataServices[0].upload(pumpEvents: events, fromSource: source, completion: completion)
        }
    }

    func upload(carbEntries entries: [StoredCarbEntry], completion: @escaping (_ entries: [StoredCarbEntry]) -> Void) {
        // TODO: How to handle completion correctly
        if !remoteDataServices.isEmpty {
            remoteDataServices[0].upload(carbEntries: entries, completion: completion)
        }
    }

    func delete(carbEntries entries: [DeletedCarbEntry], completion: @escaping (_ entries: [DeletedCarbEntry]) -> Void) {
        // TODO: How to handle completion correctly
        if !remoteDataServices.isEmpty {
            remoteDataServices[0].delete(carbEntries: entries, completion: completion)
        }
    }

    func carbStore(_ carbStore: CarbStore, hasEntriesNeedingUpload entries: [StoredCarbEntry], completion: @escaping (_ entries: [StoredCarbEntry]) -> Void) {
        upload(carbEntries: entries, completion: completion)
    }

    func carbStore(_ carbStore: CarbStore, hasDeletedEntries entries: [DeletedCarbEntry], completion: @escaping (_ entries: [DeletedCarbEntry]) -> Void) {
        delete(carbEntries: entries, completion: completion)
    }

    private var remoteDataServices: [RemoteDataService] { services.compactMap { $0 as? RemoteDataService } }

}
