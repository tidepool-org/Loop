//
//  ServicesManager.swift
//  Loop
//
//  Created by Darin Krauss on 5/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log
import LoopCore
import LoopKit
import LoopKitUI

class ServicesManager {

    private unowned let pluginManager: PluginManager

    private unowned let deviceDataManager: DeviceDataManager

    private var services = [Service]()

    private let servicesLock = UnfairLock()

    private let log = DiagnosticLog(category: "ServicesManager")

    init(pluginManager: PluginManager, deviceDataManager: DeviceDataManager) {
        self.pluginManager = pluginManager
        self.deviceDataManager = deviceDataManager

        restoreState()
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
            if var remoteDataService = service as? RemoteDataService {
                remoteDataService.remoteDataServiceDelegate = self
            }
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
            if var remoteDataService = service as? RemoteDataService {
                remoteDataService.remoteDataServiceDelegate = self
            }
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
extension ServicesManager {

    func initiateRemoteDataSynchronization() {
        remoteDataServices.forEach { remoteDataService in
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

    private var remoteDataServices: [RemoteDataService] { services.compactMap { $0 as? RemoteDataService } }

}

extension ServicesManager: RemoteDataServiceDelegate {

    var statusRemoteDataQueryDelegate: StatusRemoteDataQueryDelegate? { return deviceDataManager.loopManager!.statusStore }

    var settingsRemoteDataQueryDelegate: SettingsRemoteDataQueryDelegate? { return deviceDataManager.loopManager!.settingsStore }

    var glucoseRemoteDataQueryDelegate: GlucoseRemoteDataQueryDelegate? { return deviceDataManager.loopManager!.glucoseStore }

    var doseRemoteDataQueryDelegate: DoseRemoteDataQueryDelegate? { return deviceDataManager.loopManager!.doseStore }

    var carbRemoteDataQueryDelegate: CarbRemoteDataQueryDelegate? { return deviceDataManager.loopManager!.carbStore }

}

