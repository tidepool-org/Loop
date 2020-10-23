//
//  LoopDataManagerAlertingTests.swift
//  LoopTests
//
//  Created by Nathaniel Hamming on 2020-10-22.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit
import LoopCore
@testable import Loop

class LoopDataManagerAlertingTests: XCTestCase {

    private var alertIdentifier: Alert.Identifier?
    private var alert: Alert?
    private var testExpectation: XCTestExpectation!
    
    private lazy var settings: LoopSettings = {
        var settings = LoopSettings()
        settings.preMealTargetRange = DoubleRange(minValue: 80, maxValue: 80)
        settings.glucoseTargetRangeSchedule = GlucoseRangeSchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [.init(startTime: 0, value: DoubleRange(minValue: 95, maxValue: 105))]
        )
        settings.legacyWorkoutTargetRange = DoubleRange(minValue: 120, maxValue: 150)
        return settings
    }()

    var loopDataManager: LoopDataManager!
    
    override func setUp() {
        alert = nil
        
        let doseStore = MockDoseStore()
        let glucoseStore = MockGlucoseStore()
        let carbStore = MockCarbStore()
        
        let currentDate = glucoseStore.latestGlucose!.startDate
        
        loopDataManager = LoopDataManager(
            lastLoopCompleted: currentDate,
            basalDeliveryState: .active(currentDate),
            settings: settings,
            overrideHistory: TemporaryScheduleOverrideHistory(),
            lastPumpEventsReconciliation: nil, // this date is only used to init the doseStore if a DoseStoreProtocol isn't passed in, so this date can be nil
            analyticsServicesManager: AnalyticsServicesManager(),
            localCacheDuration: .days(1),
            doseStore: doseStore,
            glucoseStore: glucoseStore,
            carbStore: carbStore,
            dosingDecisionStore: MockDosingDecisionStore(),
            settingsStore: MockSettingsStore(),
            now: { currentDate },
            alertManager: self
        )
    }

    func testWorkoutOverrideReminderElasped() {
        testExpectation = self.expectation(description: #function)
        loopDataManager.settings.workoutOverrideReminderInterval = -.seconds(1) // the elasped time will always be greater than a negative number
        loopDataManager.settings.enableLegacyWorkoutOverride(for: .infinity)
        loopDataManager.loop()
        wait(for: [testExpectation], timeout: 1.0)
        XCTAssertEqual(alert, loopDataManager.settings.workoutOverrideReminderAlert)
    }

    func testWorkoutOverrideReminderRepeated() {
        testExpectation = self.expectation(description: #function)
        loopDataManager.settings.workoutOverrideReminderInterval = -.seconds(1) // the elasped time will always be greater than a negative number
        loopDataManager.settings.enableLegacyWorkoutOverride(for: .infinity)
        loopDataManager.loop()
        wait(for: [testExpectation], timeout: 1.0)
        XCTAssertEqual(alert, loopDataManager.settings.workoutOverrideReminderAlert)

        alert = nil
        testExpectation = self.expectation(description: #function)
        loopDataManager.loop()
        wait(for: [testExpectation], timeout: 1.0)
        XCTAssertEqual(alert, loopDataManager.settings.workoutOverrideReminderAlert)
    }

    func testWorkoutOverrideReminderNotElasped() {
        loopDataManager.settings.enableLegacyWorkoutOverride(for: .infinity)
        loopDataManager.loop()
        waitOnMain()

        XCTAssertNil(alert)
    }
}

extension LoopDataManagerAlertingTests: AlertPresenter {
    func issueAlert(_ alert: Alert) {
        self.alert = alert
        testExpectation.fulfill()
    }

    func retractAlert(identifier: Alert.Identifier) {
        alertIdentifier = identifier
    }
}
