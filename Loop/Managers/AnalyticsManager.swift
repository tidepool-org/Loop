//
//  AnalyticsManager.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 4/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopCore
import LoopKit


final class AnalyticsManager {

    private let servicesManager: ServicesManager

    private var analytics: [Analytics]

    init(servicesManager: ServicesManager) {
        self.servicesManager = servicesManager

        self.analytics = servicesManager.services.compactMap({ $0 as? Analytics })

        servicesManager.addObserver(self)
    }

    // MARK: - UIApplicationDelegate

    public func application(didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any]?) {
        recordAnalyticsEvent("App Launch")
    }

    // MARK: - Screens

    public func didDisplayBolusScreen() {
        recordAnalyticsEvent("Bolus Screen")
    }

    public func didDisplaySettingsScreen() {
        recordAnalyticsEvent("Settings Screen")
    }

    public func didDisplayStatusScreen() {
        recordAnalyticsEvent("Status Screen")
    }

    // MARK: - Config Events

    public func transmitterTimeDidDrift(_ drift: TimeInterval) {
        recordAnalyticsEvent("Transmitter time change", withProperties: ["value" : drift], outOfSession: true)
    }

    public func pumpTimeDidDrift(_ drift: TimeInterval) {
        recordAnalyticsEvent("Pump time change", withProperties: ["value": drift], outOfSession: true)
    }

    public func pumpTimeZoneDidChange() {
        recordAnalyticsEvent("Pump time zone change", outOfSession: true)
    }

    public func pumpBatteryWasReplaced() {
        recordAnalyticsEvent("Pump battery replacement", outOfSession: true)
    }

    public func reservoirWasRewound() {
        recordAnalyticsEvent("Pump reservoir rewind", outOfSession: true)
    }

    public func didChangeBasalRateSchedule() {
        recordAnalyticsEvent("Basal rate change")
    }

    public func didChangeCarbRatioSchedule() {
        recordAnalyticsEvent("Carb ratio change")
    }

    public func didChangeInsulinModel() {
        recordAnalyticsEvent("Insulin model change")
    }

    public func didChangeInsulinSensitivitySchedule() {
        recordAnalyticsEvent("Insulin sensitivity change")
    }

    public func didChangeLoopSettings(from oldValue: LoopSettings, to newValue: LoopSettings) {
        if newValue.maximumBasalRatePerHour != oldValue.maximumBasalRatePerHour {
            recordAnalyticsEvent("Maximum basal rate change")
        }

        if newValue.maximumBolus != oldValue.maximumBolus {
            recordAnalyticsEvent("Maximum bolus change")
        }

        if newValue.suspendThreshold != oldValue.suspendThreshold {
            recordAnalyticsEvent("Minimum BG Guard change")
        }

        if newValue.dosingEnabled != oldValue.dosingEnabled {
            recordAnalyticsEvent("Closed loop enabled change")
        }

        if newValue.retrospectiveCorrectionEnabled != oldValue.retrospectiveCorrectionEnabled {
            recordAnalyticsEvent("Retrospective correction enabled change")
        }

        if newValue.glucoseTargetRangeSchedule != oldValue.glucoseTargetRangeSchedule {
            if newValue.glucoseTargetRangeSchedule?.timeZone != oldValue.glucoseTargetRangeSchedule?.timeZone {
                self.pumpTimeZoneDidChange()
            } else if newValue.glucoseTargetRangeSchedule?.override != oldValue.glucoseTargetRangeSchedule?.override {
                recordAnalyticsEvent("Glucose target range override change", outOfSession: true)
            } else {
                recordAnalyticsEvent("Glucose target range change")
            }
        }
    }

    // MARK: - Loop Events

    public func didAddCarbsFromWatch() {
        recordAnalyticsEvent("Carb entry created", withProperties: ["source" : "Watch"], outOfSession: true)
    }

    public func didRetryBolus() {
        recordAnalyticsEvent("Bolus Retry", outOfSession: true)
    }

    public func didSetBolusFromWatch(_ units: Double) {
        recordAnalyticsEvent("Bolus set", withProperties: ["source" : "Watch"], outOfSession: true)
    }

    public func didFetchNewCGMData() {
        recordAnalyticsEvent("CGM Fetch", outOfSession: true)
    }

    public func loopDidSucceed() {
        recordAnalyticsEvent("Loop success", outOfSession: true)
    }

    public func loopDidError() {
        recordAnalyticsEvent("Loop error", outOfSession: true)
    }

    private func recordAnalyticsEvent(_ name: String, withProperties properties: [AnyHashable: Any]? = nil, outOfSession: Bool = false) {
        analytics.forEach { $0.recordAnalyticsEvent(name, withProperties: properties, outOfSession: outOfSession) }
    }

}


extension AnalyticsManager: ServicesManagerObserver {

    func servicesManagerDidUpdate(services: [Service]) {
        analytics = servicesManager.services.compactMap({ $0 as? Analytics })
    }
    
}
