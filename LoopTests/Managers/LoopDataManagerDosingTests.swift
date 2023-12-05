//
//  LoopDataManagerDosingTests.swift
//  LoopTests
//
//  Created by Anna Quinlan on 10/19/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit
@testable import LoopCore
@testable import Loop

@MainActor
class LoopDataManagerDosingTests: LoopDataManagerTests {
    // MARK: Functions to load fixtures
    func loadLocalDateGlucoseEffect(_ name: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(name)
        let localDateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffect(startDate: localDateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func loadPredictedGlucoseFixture(_ name: String) -> [PredictedGlucoseValue] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let url = bundle.url(forResource: name, withExtension: "json")!
        return try! decoder.decode([PredictedGlucoseValue].self, from: try! Data(contentsOf: url))
    }

    // MARK: Tests
    func testForecastFromLiveCaptureInputData() async {

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let url = bundle.url(forResource: "live_capture_input", withExtension: "json")!
        let predictionInput = try! decoder.decode(LoopPredictionInput.self, from: try! Data(contentsOf: url))

        // Therapy settings in the "live capture" input only have one value, so we can fake some schedules
        // from the first entry of each therapy setting's history.
        let basalRateSchedule = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: predictionInput.basal.first!.value)
        ])
        let insulinSensitivitySchedule = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0, value: predictionInput.sensitivity.first!.value.doubleValue(for: .milligramsPerDeciliter))
            ],
            timeZone: .utcTimeZone
        )!
        let carbRatioSchedule = CarbRatioSchedule(
            unit: .gram(),
            dailyItems: [
                RepeatingScheduleValue(startTime: 0.0, value: predictionInput.carbRatio.first!.value)
            ],
            timeZone: .utcTimeZone
        )!

        let settings = StoredSettings(
            dosingEnabled: false,
            glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
            maximumBasalRatePerHour: 10,
            maximumBolus: 5,
            suspendThreshold: GlucoseThreshold(unit: .milligramsPerDeciliter, value: 65),
            basalRateSchedule: basalRateSchedule,
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            carbRatioSchedule: carbRatioSchedule,
            automaticDosingStrategy: .automaticBolus
        )

        let settingsProvider = MockSettingsProvider(settings: settings)

        let glucoseStore = MockGlucoseStore()
        glucoseStore.storedGlucose = predictionInput.glucoseHistory

        let currentDate = glucoseStore.latestGlucose!.startDate
        now = currentDate

        let doseStore = MockDoseStore()
        doseStore.doseHistory = predictionInput.doses
        doseStore.lastAddedPumpData = predictionInput.doses.last!.startDate
        let carbStore = MockCarbStore()
        carbStore.carbHistory = predictionInput.carbEntries

        let temporaryPresetsManager = TemporaryPresetsManager(settingsProvider: settingsProvider)

        dosingDecisionStore = MockDosingDecisionStore()
        automaticDosingStatus = AutomaticDosingStatus(automaticDosingEnabled: true, isAutomaticDosingAllowed: true)
        loopDataManager = LoopDataManager(
            lastLoopCompleted: currentDate,
            temporaryPresetsManager: temporaryPresetsManager,
            settingsProvider: settingsProvider,
            doseStore: doseStore,
            glucoseStore: glucoseStore,
            carbStore: carbStore,
            dosingDecisionStore: dosingDecisionStore,
            now: { currentDate },
            automaticDosingStatus: automaticDosingStatus,
            trustedTimeOffset: { 0 },
            analyticsServicesManager: AnalyticsServicesManager()
        )

        let expectedPredictedGlucose = loadPredictedGlucoseFixture("live_capture_predicted_glucose")

        await loopDataManager.updateDisplayState()

        guard let predictedGlucose = loopDataManager.predictedGlucose else {
            XCTFail("No prediction!")
            return
        }

        guard let recommendedBasal = loopDataManager.tempBasalRecommendation else {
            XCTFail("No recommendation!")
            return
        }

        XCTAssertNotNil(predictedGlucose)

        XCTAssertEqual(expectedPredictedGlucose.count, predictedGlucose.count)
        XCTAssertEqual(0, recommendedBasal.unitsPerHour)

        for (expected, calculated) in zip(expectedPredictedGlucose, predictedGlucose) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }
    }


    func testFlatAndStable() async {
        await setUp(for: .flatAndStable)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("flat_and_stable_predicted_glucose")

        let predictedGlucose = loopDataManager.predictedGlucose
        let recommendedDose = loopDataManager.automaticRecommendation

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)

        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }
        
        let recommendedTempBasal = recommendedDose?.basalAdjustment

        XCTAssertEqual(1.40, recommendedTempBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }
    
    func testHighAndStable() async {
        await setUp(for: .highAndStable)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("high_and_stable_predicted_glucose")

        let predictedGlucose = loopDataManager.predictedGlucose
        let recommendedBasal = loopDataManager.tempBasalRecommendation

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }

        XCTAssertEqual(4.63, recommendedBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }
    
    func testHighAndFalling() async {
        await setUp(for: .highAndFalling)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("high_and_falling_predicted_glucose")

        let predictedGlucose = loopDataManager.predictedGlucose
        let recommendedTempBasal = loopDataManager.tempBasalRecommendation

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }

        XCTAssertEqual(0, recommendedTempBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }
    
    func testHighAndRisingWithCOB() async {
        await setUp(for: .highAndRisingWithCOB)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("high_and_rising_with_cob_predicted_glucose")

        let predictedGlucose = loopDataManager.predictedGlucose
        let recommendedBolus = loopDataManager.automaticBolusRecommendation

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }

        XCTAssertEqual(1.6, recommendedBolus!, accuracy: defaultAccuracy)
    }
    
    func testLowAndFallingWithCOB() async {
        await setUp(for: .lowAndFallingWithCOB)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("low_and_falling_predicted_glucose")

        let predictedGlucose = loopDataManager.predictedGlucose
        let recommendedTempBasal = loopDataManager.tempBasalRecommendation

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }

        XCTAssertEqual(0, recommendedTempBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }
    
    func testLowWithLowTreatment() async {
        await setUp(for: .lowWithLowTreatment)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("low_with_low_treatment_predicted_glucose")

        let predictedGlucose = loopDataManager.predictedGlucose
        let recommendedTempBasal = loopDataManager.tempBasalRecommendation

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }

        XCTAssertEqual(0, recommendedTempBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }

    func testOpenLoopCancelsTempBasal() async {
        let dose = DoseEntry(type: .tempBasal, startDate: Date(), value: 1.0, unit: .unitsPerHour)
        await setUp(for: .highAndStable, basalDeliveryState: .tempBasal(dose))

        let exp = expectation(description: #function)
        let observer = NotificationCenter.default.addObserver(forName: .LoopDataUpdated, object: nil, queue: nil) { _ in
            exp.fulfill()
        }
        automaticDosingStatus.automaticDosingEnabled = false
        await fulfillment(of: [exp])

        let expectedAutomaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: .cancel)
        XCTAssertEqual(deliveryDelegate.lastEnact, expectedAutomaticDoseRecommendation)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "automaticDosingDisabled")
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, expectedAutomaticDoseRecommendation)
        NotificationCenter.default.removeObserver(observer)
    }

    func testLoopEnactsTempBasalWithoutManualBolusRecommendation() async {
        await setUp(for: .highAndStable)

        let exp = expectation(description: #function)
        let observer = NotificationCenter.default.addObserver(forName: .LoopCycleCompleted, object: nil, queue: nil) { _ in
            exp.fulfill()
        }
        await loopDataManager.loop()

        await fulfillment(of: [exp])

        let expectedAutomaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: TempBasalRecommendation(unitsPerHour: 4.55, duration: .minutes(30)))
        XCTAssertEqual(deliveryDelegate.lastEnact, expectedAutomaticDoseRecommendation)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        if dosingDecisionStore.dosingDecisions.count == 1 {
            XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "loop")
            XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, expectedAutomaticDoseRecommendation)
            XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRecommendation)
            XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRequested)
        }
        NotificationCenter.default.removeObserver(observer)
    }

    func testLoopRecommendsTempBasalWithoutEnactingIfOpenLoop() async {
        await setUp(for: .highAndStable)
        automaticDosingStatus.automaticDosingEnabled = false

        let exp = expectation(description: #function)
        let observer = NotificationCenter.default.addObserver(forName: .LoopCycleCompleted, object: nil, queue: nil) { _ in
            exp.fulfill()
        }
        await loopDataManager.loop()

        await fulfillment(of: [exp])

        let expectedAutomaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: TempBasalRecommendation(unitsPerHour: 4.55, duration: .minutes(30)))
        XCTAssertNil(deliveryDelegate.lastEnact)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "loop")
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, expectedAutomaticDoseRecommendation)
        XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRecommendation)
        XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRequested)
        NotificationCenter.default.removeObserver(observer)
    }

    func testIsClosedLoopAvoidsTriggeringTempBasalCancelOnCreation() {
        let settings = StoredSettings(
            dosingEnabled: false,
            glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
            maximumBasalRatePerHour: 5,
            maximumBolus: 10,
            suspendThreshold: suspendThreshold
        )

        let doseStore = MockDoseStore()
        let glucoseStore = MockGlucoseStore(for: .flatAndStable)
        let carbStore = MockCarbStore()

        let currentDate = Date()

        dosingDecisionStore = MockDosingDecisionStore()
        automaticDosingStatus = AutomaticDosingStatus(automaticDosingEnabled: false, isAutomaticDosingAllowed: true)
        let existingTempBasal = DoseEntry(
            type: .tempBasal,
            startDate: currentDate.addingTimeInterval(-.minutes(2)),
            endDate: currentDate.addingTimeInterval(.minutes(28)),
            value: 1.0,
            unit: .unitsPerHour,
            deliveredUnits: nil,
            description: "Mock Temp Basal",
            syncIdentifier: "asdf",
            scheduledBasalRate: nil,
            insulinType: .novolog,
            automatic: true,
            manuallyEntered: false,
            isMutable: true)

        let settingsProvider = MockSettingsProvider(settings: settings)
        let temporaryPresetsManager = TemporaryPresetsManager(settingsProvider: settingsProvider)

        loopDataManager = LoopDataManager(
            lastLoopCompleted: currentDate.addingTimeInterval(-.minutes(5)),
            temporaryPresetsManager: temporaryPresetsManager,
            settingsProvider: settingsProvider,
            doseStore: doseStore,
            glucoseStore: glucoseStore,
            carbStore: carbStore,
            dosingDecisionStore: dosingDecisionStore,
            now: { currentDate },
            automaticDosingStatus: automaticDosingStatus,
            trustedTimeOffset: { 0 },
            analyticsServicesManager: nil
        )

        let deliveryDelegate = MockDeliveryDelegate()

        deliveryDelegate.basalDeliveryState = .tempBasal(existingTempBasal)

        loopDataManager.deliveryDelegate = deliveryDelegate

        // Dose enacting happens asynchronously, as does receiving isClosedLoop signals
        waitOnMain(timeout: 5)
        XCTAssertNil(deliveryDelegate.lastEnact)
    }

    // TODO: Implement as LoopAlgorithm test
//    func testAutoBolusMaxIOBClamping() async {
//        /// `maxBolus` is set to clamp the automatic dose
//        /// Autobolus without clamping: 0.65 U. Clamped recommendation: 0.2 U.
//        await setUp(for: .highAndRisingWithCOB, maxBolus: 5, dosingStrategy: .automaticBolus)
//
//        var insulinOnBoard: InsulinValue?
//        var recommendedBolus: Double?
//        self.loopDataManager.getLoopState { _, state in
//            insulinOnBoard = state.insulinOnBoard
//            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
//            updateGroup.leave()
//        }
//        updateGroup.wait()
//
//        XCTAssertEqual(recommendedBolus!, 0.5, accuracy: 0.01)
//        XCTAssertEqual(insulinOnBoard?.value, 9.5)
//
//        /// Set the `maximumBolus` to 10U so there's no clamping
//        updateGroup.enter()
//        self.loopDataManager.mutateSettings { settings in settings.maximumBolus = 10 }
//        self.loopDataManager.getLoopState { _, state in
//            insulinOnBoard = state.insulinOnBoard
//            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
//            updateGroup.leave()
//        }
//        updateGroup.wait()
//
//        XCTAssertEqual(recommendedBolus!, 0.65, accuracy: 0.01)
//        XCTAssertEqual(insulinOnBoard?.value, 9.5)
//    }

    // TODO: Implement as LoopAlgorithm test

//    func testTempBasalMaxIOBClamping() {
//        /// `maximumBolus` is set to 5U to clamp max IOB at 10U
//        /// Without clamping: 4.25 U/hr. Clamped recommendation: 2.0 U/hr.
//        setUp(for: .highAndRisingWithCOB, maxBolus: 5)
//
//        // This sets up dose rounding
//        let delegate = MockDelegate()
//        loopDataManager.delegate = delegate
//
//        let updateGroup = DispatchGroup()
//        updateGroup.enter()
//
//        var insulinOnBoard: InsulinValue?
//        var recommendedBasal: TempBasalRecommendation?
//        self.loopDataManager.getLoopState { _, state in
//            insulinOnBoard = state.insulinOnBoard
//            recommendedBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
//            updateGroup.leave()
//        }
//        updateGroup.wait()
//
//        XCTAssertEqual(recommendedBasal!.unitsPerHour, 2.0, accuracy: 0.01)
//        XCTAssertEqual(insulinOnBoard?.value, 9.5)
//
//        /// Set the `maximumBolus` to 10U so there's no clamping
//        updateGroup.enter()
//        self.loopDataManager.mutateSettings { settings in settings.maximumBolus = 10 }
//        self.loopDataManager.getLoopState { _, state in
//            insulinOnBoard = state.insulinOnBoard
//            recommendedBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
//            updateGroup.leave()
//        }
//        updateGroup.wait()
//
//        XCTAssertEqual(recommendedBasal!.unitsPerHour, 4.25, accuracy: 0.01)
//        XCTAssertEqual(insulinOnBoard?.value, 9.5)
//    }

}
