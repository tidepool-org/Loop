//
//  LoopDataManagerTests.swift
//  LoopTests
//
//  Created by Anna Quinlan on 8/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit
import HealthKit
@testable import LoopCore
@testable import Loop

public typealias JSONDictionary = [String: Any]

extension TimeZone {
    static var fixtureTimeZone: TimeZone {
        return TimeZone(secondsFromGMT: 25200)!
    }
    
    static var utcTimeZone: TimeZone {
        return TimeZone(secondsFromGMT: 0)!
    }
}

extension ISO8601DateFormatter {
    static func localTimeDate(timeZone: TimeZone = .fixtureTimeZone) -> Self {
        let formatter = self.init()

        formatter.formatOptions = .withInternetDateTime
        formatter.formatOptions.subtract(.withTimeZone)
        formatter.timeZone = timeZone

        return formatter
    }
}

@MainActor
class LoopDataManagerTests: XCTestCase {
    // MARK: Constants for testing
    let retrospectiveCorrectionEffectDuration = TimeInterval(hours: 1)
    let retrospectiveCorrectionGroupingInterval = 1.01
    let retrospectiveCorrectionGroupingIntervalMultiplier = 1.01
    let inputDataRecencyInterval = TimeInterval(minutes: 15)
    let dateFormatter = ISO8601DateFormatter.localTimeDate()
    let defaultAccuracy = 1.0 / 40.0
    
    var suspendThreshold: GlucoseThreshold {
        return GlucoseThreshold(unit: HKUnit.milligramsPerDeciliter, value: 75)
    }
    
    var adultExponentialInsulinModel: InsulinModel = ExponentialInsulinModel(actionDuration: 21600.0, peakActivityTime: 4500.0)

    var glucoseTargetRangeSchedule: GlucoseRangeSchedule {
        return GlucoseRangeSchedule(unit: HKUnit.milligramsPerDeciliter, dailyItems: [
            RepeatingScheduleValue(startTime: TimeInterval(0), value: DoubleRange(minValue: 100, maxValue: 110)),
            RepeatingScheduleValue(startTime: TimeInterval(28800), value: DoubleRange(minValue: 90, maxValue: 100)),
            RepeatingScheduleValue(startTime: TimeInterval(75600), value: DoubleRange(minValue: 100, maxValue: 110))
        ], timeZone: .utcTimeZone)!
    }
    
    // MARK: Stores
    var now: Date!
    let persistenceController = PersistenceController.mock()
    var doseStore = MockDoseStore()
    var glucoseStore = MockGlucoseStore()
    var carbStore = MockCarbStore()
    var dosingDecisionStore: MockDosingDecisionStore!
    var automaticDosingStatus: AutomaticDosingStatus!
    var loopDataManager: LoopDataManager!
    var deliveryDelegate: MockDeliveryDelegate!
    var settingsProvider: MockSettingsProvider!

    func d(_ interval: TimeInterval) -> Date {
        return now.addingTimeInterval(interval)
    }

    override func setUp() async throws {
        let basalRateSchedule = loadBasalRateScheduleFixture("basal_profile")
        let insulinSensitivitySchedule = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0, value: 45),
                RepeatingScheduleValue(startTime: 32400, value: 55)
            ],
            timeZone: .utcTimeZone
        )!
        let carbRatioSchedule = CarbRatioSchedule(
            unit: .gram(),
            dailyItems: [
                RepeatingScheduleValue(startTime: 0.0, value: 10.0),
            ],
            timeZone: .utcTimeZone
        )!

        let settings = StoredSettings(
            dosingEnabled: false,
            glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
            maximumBasalRatePerHour: 6,
            maximumBolus: 5,
            suspendThreshold: suspendThreshold,
            basalRateSchedule: basalRateSchedule,
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            carbRatioSchedule: carbRatioSchedule,
            automaticDosingStrategy: .automaticBolus
        )

        settingsProvider = MockSettingsProvider(settings: settings)

        now = dateFormatter.date(from: "2023-07-29T19:21:00Z")!

        dosingDecisionStore = MockDosingDecisionStore()
        automaticDosingStatus = AutomaticDosingStatus(automaticDosingEnabled: true, isAutomaticDosingAllowed: true)

        let temporaryPresetsManager = TemporaryPresetsManager(settingsProvider: settingsProvider)

        loopDataManager = LoopDataManager(
            lastLoopCompleted: now,
            temporaryPresetsManager: temporaryPresetsManager,
            settingsProvider: settingsProvider,
            doseStore: doseStore,
            glucoseStore: glucoseStore,
            carbStore: carbStore,
            dosingDecisionStore: dosingDecisionStore,
            now: { [weak self] in self?.now ?? Date() },
            automaticDosingStatus: automaticDosingStatus,
            trustedTimeOffset: { 0 },
            analyticsServicesManager: nil,
            carbAbsorptionModel: .piecewiseLinear
        )

        deliveryDelegate = MockDeliveryDelegate()
        loopDataManager.deliveryDelegate = deliveryDelegate

        deliveryDelegate.basalDeliveryState = .active(now.addingTimeInterval(-.hours(2)))
    }

    func testCancellingTempBasalShouldStoreDosingDecision() {
        // TODO
//        XCTAssertEqual(mockDecisionStore.dosingDecisions.count, 1)
//        XCTAssertEqual(mockDecisionStore.dosingDecisions[0].reason, "maximumBasalRateChanged")
//        XCTAssertEqual(mockDecisionStore.dosingDecisions[0].automaticDoseRecommendation, AutomaticDoseRecommendation(basalAdjustment: .cancel))
//
    }

    override func tearDownWithError() throws {
        loopDataManager = nil
    }

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

        settingsProvider.settings = StoredSettings(
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

        glucoseStore.storedGlucose = predictionInput.glucoseHistory

        let currentDate = glucoseStore.latestGlucose!.startDate
        now = currentDate

        doseStore.doseHistory = predictionInput.doses
        doseStore.lastAddedPumpData = predictionInput.doses.last!.startDate
        carbStore.carbHistory = predictionInput.carbEntries

        let expectedPredictedGlucose = loadPredictedGlucoseFixture("live_capture_predicted_glucose")

        await loopDataManager.updateDisplayState()

        let predictedGlucose = loopDataManager.displayState.output?.predictedGlucose

        XCTAssertNotNil(predictedGlucose)

        XCTAssertEqual(expectedPredictedGlucose.count, predictedGlucose!.count)

        for (expected, calculated) in zip(expectedPredictedGlucose, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }

        await loopDataManager.loop()

        XCTAssertEqual(0, deliveryDelegate.lastEnact?.bolusUnits)
        XCTAssertEqual(0, deliveryDelegate.lastEnact?.basalAdjustment?.unitsPerHour)
    }


    func testHighAndStable() async {
        glucoseStore.storedGlucose = [
            StoredGlucoseSample(startDate: d(.minutes(-1)), quantity: .glucose(value: 120)),
        ]

        await loopDataManager.updateDisplayState()

        XCTAssertEqual(120, loopDataManager.eventualBG)
        XCTAssert(loopDataManager.displayState.output!.effects.momentum.isEmpty)

        await loopDataManager.loop()

        XCTAssertEqual(0.2, deliveryDelegate.lastEnact!.bolusUnits!, accuracy: defaultAccuracy)
    }


    func testHighAndFalling() async {
        glucoseStore.storedGlucose = [
            StoredGlucoseSample(startDate: d(.minutes(-18)), quantity: .glucose(value: 200)),
            StoredGlucoseSample(startDate: d(.minutes(-13)), quantity: .glucose(value: 190)),
            StoredGlucoseSample(startDate: d(.minutes(-8)), quantity: .glucose(value: 180)),
            StoredGlucoseSample(startDate: d(.minutes(-3)), quantity: .glucose(value: 170)),
        ]

        await loopDataManager.updateDisplayState()

        XCTAssertEqual(150, loopDataManager.eventualBG)
        XCTAssert(!loopDataManager.displayState.output!.effects.momentum.isEmpty)

        await loopDataManager.loop()

        // Should correct high.
        XCTAssertEqual(0.4, deliveryDelegate.lastEnact!.bolusUnits!, accuracy: defaultAccuracy)
    }

    func testHighAndRisingWithCOB() async {
        glucoseStore.storedGlucose = [
            StoredGlucoseSample(startDate: d(.minutes(-18)), quantity: .glucose(value: 200)),
            StoredGlucoseSample(startDate: d(.minutes(-13)), quantity: .glucose(value: 210)),
            StoredGlucoseSample(startDate: d(.minutes(-8)), quantity: .glucose(value: 220)),
            StoredGlucoseSample(startDate: d(.minutes(-3)), quantity: .glucose(value: 230)),
        ]

        await loopDataManager.updateDisplayState()

        XCTAssertEqual(250, loopDataManager.eventualBG)
        XCTAssert(!loopDataManager.displayState.output!.effects.momentum.isEmpty)

        await loopDataManager.loop()

        // Should correct high.
        XCTAssertEqual(1.15, deliveryDelegate.lastEnact!.bolusUnits!, accuracy: defaultAccuracy)
    }

    func testLowAndFalling() async {
        glucoseStore.storedGlucose = [
            StoredGlucoseSample(startDate: d(.minutes(-18)), quantity: .glucose(value: 100)),
            StoredGlucoseSample(startDate: d(.minutes(-13)), quantity: .glucose(value: 95)),
            StoredGlucoseSample(startDate: d(.minutes(-8)), quantity: .glucose(value: 90)),
            StoredGlucoseSample(startDate: d(.minutes(-3)), quantity: .glucose(value: 85)),
        ]

        await loopDataManager.updateDisplayState()

        XCTAssertEqual(75, loopDataManager.eventualBG!, accuracy: 1.0)
        XCTAssert(!loopDataManager.displayState.output!.effects.momentum.isEmpty)

        await loopDataManager.loop()

        // Should not bolus, and should low temp.
        XCTAssertEqual(0, deliveryDelegate.lastEnact!.bolusUnits!, accuracy: defaultAccuracy)
        XCTAssertEqual(0, deliveryDelegate.lastEnact!.basalAdjustment!.unitsPerHour, accuracy: defaultAccuracy)
    }


    func testLowAndFallingWithCOB() async {
        glucoseStore.storedGlucose = [
            StoredGlucoseSample(startDate: d(.minutes(-18)), quantity: .glucose(value: 100)),
            StoredGlucoseSample(startDate: d(.minutes(-13)), quantity: .glucose(value: 95)),
            StoredGlucoseSample(startDate: d(.minutes(-8)), quantity: .glucose(value: 90)),
            StoredGlucoseSample(startDate: d(.minutes(-3)), quantity: .glucose(value: 85)),
        ]

        carbStore.carbHistory = [
            StoredCarbEntry(startDate: d(.minutes(-5)), quantity: .carbs(value: 20))
        ]

        await loopDataManager.updateDisplayState()

        XCTAssertEqual(185, loopDataManager.eventualBG!, accuracy: 1.0)
        XCTAssert(!loopDataManager.displayState.output!.effects.momentum.isEmpty)

        await loopDataManager.loop()

        // Because eventual is high, but mid-term is low, stay neutral in delivery.
        XCTAssertEqual(0, deliveryDelegate.lastEnact!.bolusUnits!, accuracy: defaultAccuracy)
        XCTAssertNil(deliveryDelegate.lastEnact!.basalAdjustment)
    }

    func testOpenLoopCancelsTempBasal() async {
        glucoseStore.storedGlucose = [
            StoredGlucoseSample(startDate: d(.minutes(-1)), quantity: .glucose(value: 150)),
        ]

        let dose = DoseEntry(type: .tempBasal, startDate: Date(), value: 1.0, unit: .unitsPerHour)
        deliveryDelegate.basalDeliveryState = .tempBasal(dose)

        let exp = expectation(description: #function)
        let observer = NotificationCenter.default.addObserver(forName: .LoopDataUpdated, object: nil, queue: nil) { _ in
            exp.fulfill()
        }

        automaticDosingStatus.automaticDosingEnabled = false

        await fulfillment(of: [exp], timeout: 1.0)

        let expectedAutomaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: .cancel)
        XCTAssertEqual(deliveryDelegate.lastEnact, expectedAutomaticDoseRecommendation)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "automaticDosingDisabled")
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, expectedAutomaticDoseRecommendation)
        NotificationCenter.default.removeObserver(observer)
    }

    func testLoopEnactsTempBasalWithoutManualBolusRecommendation() async {
        glucoseStore.storedGlucose = [
            StoredGlucoseSample(startDate: d(.minutes(-1)), quantity: .glucose(value: 150)),
        ]

        settingsProvider.settings.automaticDosingStrategy = .tempBasalOnly

        await loopDataManager.loop()

        let expectedAutomaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: TempBasalRecommendation(unitsPerHour: 3.0, duration: .minutes(30)))
        XCTAssertEqual(deliveryDelegate.lastEnact, expectedAutomaticDoseRecommendation)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        if dosingDecisionStore.dosingDecisions.count == 1 {
            XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "loop")
            XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, expectedAutomaticDoseRecommendation)
            XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRecommendation)
            XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRequested)
        }
    }

    func testLoopRecommendsTempBasalWithoutEnactingIfOpenLoop() async {
        glucoseStore.storedGlucose = [
            StoredGlucoseSample(startDate: d(.minutes(-1)), quantity: .glucose(value: 150)),
        ]
        automaticDosingStatus.automaticDosingEnabled = false
        settingsProvider.settings.automaticDosingStrategy = .tempBasalOnly

        await loopDataManager.loop()

        let expectedAutomaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: TempBasalRecommendation(unitsPerHour: 3.0, duration: .minutes(30)))
        XCTAssertNil(deliveryDelegate.lastEnact)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "loop")
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, expectedAutomaticDoseRecommendation)
        XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRecommendation)
        XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRequested)
    }

    func testLoopGetStateRecommendsManualBolusWithoutMomentum() async {
        glucoseStore.storedGlucose = [
            StoredGlucoseSample(startDate: d(.minutes(-18)), quantity: .glucose(value: 100)),
            StoredGlucoseSample(startDate: d(.minutes(-13)), quantity: .glucose(value: 130)),
            StoredGlucoseSample(startDate: d(.minutes(-8)), quantity: .glucose(value: 160)),
            StoredGlucoseSample(startDate: d(.minutes(-3)), quantity: .glucose(value: 190)),
        ]

        loopDataManager.usePositiveMomentumAndRCForManualBoluses = true
        var recommendation = try! await loopDataManager.recommendManualBolus()!
        XCTAssertEqual(recommendation.amount, 2.46, accuracy: 0.01)

        loopDataManager.usePositiveMomentumAndRCForManualBoluses = false
        recommendation = try! await loopDataManager.recommendManualBolus()!
        XCTAssertEqual(recommendation.amount, 1.73, accuracy: 0.01)

    }


// TODO:
//    func testIsClosedLoopAvoidsTriggeringTempBasalCancelOnCreation() {
//        let settings = StoredSettings(
//            dosingEnabled: false,
//            glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
//            maximumBasalRatePerHour: 5,
//            maximumBolus: 10,
//            suspendThreshold: suspendThreshold
//        )
//
//        let doseStore = MockDoseStore()
//        let glucoseStore = MockGlucoseStore(for: .flatAndStable)
//        let carbStore = MockCarbStore()
//
//        let currentDate = Date()
//
//        dosingDecisionStore = MockDosingDecisionStore()
//        automaticDosingStatus = AutomaticDosingStatus(automaticDosingEnabled: false, isAutomaticDosingAllowed: true)
//        let existingTempBasal = DoseEntry(
//            type: .tempBasal,
//            startDate: currentDate.addingTimeInterval(-.minutes(2)),
//            endDate: currentDate.addingTimeInterval(.minutes(28)),
//            value: 1.0,
//            unit: .unitsPerHour,
//            deliveredUnits: nil,
//            description: "Mock Temp Basal",
//            syncIdentifier: "asdf",
//            scheduledBasalRate: nil,
//            insulinType: .novolog,
//            automatic: true,
//            manuallyEntered: false,
//            isMutable: true)
//
//        let settingsProvider = MockSettingsProvider(settings: settings)
//        let temporaryPresetsManager = TemporaryPresetsManager(settingsProvider: settingsProvider)
//
//        loopDataManager = LoopDataManager(
//            lastLoopCompleted: currentDate.addingTimeInterval(-.minutes(5)),
//            temporaryPresetsManager: temporaryPresetsManager,
//            settingsProvider: settingsProvider,
//            doseStore: doseStore,
//            glucoseStore: glucoseStore,
//            carbStore: carbStore,
//            dosingDecisionStore: dosingDecisionStore,
//            now: { currentDate },
//            automaticDosingStatus: automaticDosingStatus,
//            trustedTimeOffset: { 0 },
//            analyticsServicesManager: nil
//        )
//
//        let deliveryDelegate = MockDeliveryDelegate()
//
//        deliveryDelegate.basalDeliveryState = .tempBasal(existingTempBasal)
//
//        loopDataManager.deliveryDelegate = deliveryDelegate
//
//        // Dose enacting happens asynchronously, as does receiving isClosedLoop signals
//        waitOnMain(timeout: 5)
//        XCTAssertNil(deliveryDelegate.lastEnact)
//    }

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

extension LoopDataManagerTests {
    public var bundle: Bundle {
        return Bundle(for: type(of: self))
    }

    public func loadFixture<T>(_ resourceName: String) -> T {
        let path = bundle.path(forResource: resourceName, ofType: "json")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)), options: []) as! T
    }
    
    func loadBasalRateScheduleFixture(_ resourceName: String) -> BasalRateSchedule {
        let fixture: [JSONDictionary] = loadFixture(resourceName)

        let items = fixture.map {
            return RepeatingScheduleValue(startTime: TimeInterval(minutes: $0["minutes"] as! Double), value: $0["rate"] as! Double)
        }

        return BasalRateSchedule(dailyItems: items, timeZone: .utcTimeZone)!
    }
}

extension HKQuantity {
    static func glucose(value: Double) -> HKQuantity {
        return .init(unit: .milligramsPerDeciliter, doubleValue: value)
    }

    static func carbs(value: Double) -> HKQuantity {
        return .init(unit: .gram(), doubleValue: value)
    }

}

extension LoopDataManager {
    var eventualBG: Double? {
        displayState.output?.predictedGlucose.last?.quantity.doubleValue(for: .milligramsPerDeciliter)
    }
}
