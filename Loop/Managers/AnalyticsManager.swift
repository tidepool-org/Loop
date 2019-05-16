//
//  AnalyticsManager.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 4/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit


final class AnalyticsManager: Analytics {

    private let servicesManager: ServicesManager

    private var analytics: [Analytics]

    init(servicesManager: ServicesManager) {
        self.servicesManager = servicesManager

        self.analytics = servicesManager.services.compactMap({ $0 as? Analytics })

        servicesManager.addObserver(self)
    }

    // MARK: - UIApplicationDelegate

    func application(didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any]?) {
        analytics.forEach { $0.application(didFinishLaunchingWithOptions: launchOptions) }
    }

    // MARK: - Screens

    func didDisplayBolusScreen() {
        analytics.forEach { $0.didDisplayBolusScreen() }
    }

    func didDisplaySettingsScreen() {
        analytics.forEach { $0.didDisplaySettingsScreen() }
    }

    func didDisplayStatusScreen() {
        analytics.forEach { $0.didDisplayStatusScreen() }
    }

    // MARK: - Config Events

    func transmitterTimeDidDrift(_ drift: TimeInterval) {
        analytics.forEach { $0.transmitterTimeDidDrift(drift) }
    }

    func pumpTimeDidDrift(_ drift: TimeInterval) {
        analytics.forEach { $0.pumpTimeDidDrift(drift) }
    }

    func pumpTimeZoneDidChange() {
        analytics.forEach { $0.pumpTimeZoneDidChange() }
    }

    func pumpBatteryWasReplaced() {
        analytics.forEach { $0.pumpBatteryWasReplaced() }
    }

    func reservoirWasRewound() {
        analytics.forEach { $0.reservoirWasRewound() }
    }

    func didChangeBasalRateSchedule() {
        analytics.forEach { $0.didChangeBasalRateSchedule() }
    }

    func didChangeCarbRatioSchedule() {
        analytics.forEach { $0.didChangeCarbRatioSchedule() }
    }

    func didChangeInsulinModel() {
        analytics.forEach { $0.didChangeInsulinModel() }
    }

    func didChangeInsulinSensitivitySchedule() {
        analytics.forEach { $0.didChangeInsulinSensitivitySchedule() }
    }

    func didChangeLoopSettings(from oldValue: LoopSettings, to newValue: LoopSettings) {
        analytics.forEach { $0.didChangeLoopSettings(from: oldValue, to: newValue) }
    }

    // MARK: - Loop Events

    func didAddCarbsFromWatch() {
        analytics.forEach { $0.didAddCarbsFromWatch() }
    }

    func didRetryBolus() {
        analytics.forEach { $0.didRetryBolus() }
    }

    func didSetBolusFromWatch(_ units: Double) {
        analytics.forEach { $0.didSetBolusFromWatch(units) }
    }

    func didFetchNewCGMData() {
        analytics.forEach { $0.didFetchNewCGMData() }
    }

    func loopDidSucceed() {
        analytics.forEach { $0.loopDidSucceed() }
    }

    func loopDidError() {
        analytics.forEach { $0.loopDidError() }
    }

}


extension AnalyticsManager: ServicesManagerObserver {

    func servicesManagerDidUpdate(services: [Service]) {
        analytics = servicesManager.services.compactMap({ $0 as? Analytics })
    }
    
}
