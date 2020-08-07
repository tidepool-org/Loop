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
@testable import Loop

public typealias JSONDictionary = [String: Any]

extension TimeZone {
    static var currentFixed: TimeZone {
        return TimeZone(secondsFromGMT: TimeZone.current.secondsFromGMT())!
    }
}

extension ISO8601DateFormatter {
    static func localTimeDate(timeZone: TimeZone = .currentFixed) -> Self {
        let formatter = self.init()

        formatter.formatOptions = .withInternetDateTime
        formatter.formatOptions.subtract(.withTimeZone)
        formatter.timeZone = timeZone

        return formatter
    }
}

extension DoseUnit {
    var unit: HKUnit {
        switch self {
        case .units:
            return .internationalUnit()
        case .unitsPerHour:
            return HKUnit(from: "IU/hr")
        }
    }
}

class MockGlucoseStore: GlucoseStoreTestingProtocol {
    func getRecentMomentumEffect(_ completion: @escaping (_ effects: [GlucoseEffect]) -> Void) {
        let fixture: [JSONDictionary] = loadFixture("momentum_effect_bouncing")
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return completion(fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue: $0["amount"] as! Double))
            }
        )
    }
    
    func getCounteractionEffects(start: Date, end: Date? = nil, to effects: [GlucoseEffect], _ completion: @escaping (_ effects: [GlucoseEffectVelocity]) -> Void) {
        let fixture: [JSONDictionary] = loadFixture("counteraction_effect_falling_glucose")
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return completion(fixture.map {
            return GlucoseEffectVelocity(startDate: dateFormatter.date(from: $0["startDate"] as! String)!, endDate: dateFormatter.date(from: $0["endDate"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["value"] as! Double))
        })
    }
}

extension MockGlucoseStore {
    public var bundle: Bundle {
        return Bundle(for: type(of: self))
    }

    public func loadFixture<T>(_ resourceName: String) -> T {
        let path = bundle.path(forResource: resourceName, ofType: "json")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)), options: []) as! T
    }
}

class MockCarbStore: CarbStoreTestingProtocol {
    func getGlucoseEffects(start: Date, end: Date? = nil, effectVelocities: [GlucoseEffectVelocity]?, completion: @escaping(_ result: CarbStoreResult<(samples: [StoredCarbEntry], effects: [GlucoseEffect])>) -> Void) {
        let fixture: [JSONDictionary] = loadFixture("dynamic_glucose_effect_partially_observed")
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return completion(.success(([], fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        })))
    }
}

extension MockCarbStore {
    public var bundle: Bundle {
        return Bundle(for: type(of: self))
    }

    public func loadFixture<T>(_ resourceName: String) -> T {
        let path = bundle.path(forResource: resourceName, ofType: "json")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)), options: []) as! T
    }
}

class LoopDataManagerDosingTests: XCTestCase {
    /// MARK: constants for testing
    let retrospectiveCorrectionEffectDuration = TimeInterval(hours: 1)
    let retrospectiveCorrectionGroupingInterval = 1.01
    let retrospectiveCorrectionGroupingIntervalMultiplier = 1.01
    let inputDataRecencyInterval = TimeInterval(minutes: 15)
    let dateFormatter = ISO8601DateFormatter.localTimeDate()
    
    let maxBasalRate = 5.0
    
    var suspendThreshold: GlucoseThreshold {
        return GlucoseThreshold(unit: HKUnit.milligramsPerDeciliter, value: 55)
    }
    
    var exponentialInsulinModel: InsulinModel = ExponentialInsulinModel(actionDuration: 21600.0, peakActivityTime: 4500.0)
    
    var insulinSensitivitySchedule: InsulinSensitivitySchedule {
        return InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0.0, value: 60.0)])!
    }
    
    var walshInsulinModel: InsulinModel {
        return WalshInsulinModel(actionDuration: insulinActionDuration)
    }

    var insulinActionDuration: TimeInterval {
        return TimeInterval(hours: 4)
    }
    
    var basalRateSchedule: BasalRateSchedule {
        return loadBasalRateScheduleFixture("basal_profile")
    }

    var glucoseTargetRangeSchedule: GlucoseRangeSchedule {
        return GlucoseRangeSchedule(unit: HKUnit.milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: TimeInterval(0), value: DoubleRange(minValue: 90, maxValue: 120))])!
    }
    
    /// MARK: mock stores
    var doseStore: DoseStoreProtocol!
    var glucoseStore: GlucoseStoreTestingProtocol!
    var carbStore: CarbStoreTestingProtocol!
    var retrospectiveCorrection: RetrospectiveCorrection!
    
    override func setUp() {
        super.setUp()
        doseStore = MockDoseStore()
        glucoseStore = MockGlucoseStore()
        carbStore = MockCarbStore()
        retrospectiveCorrection = StandardRetrospectiveCorrection(effectDuration: retrospectiveCorrectionEffectDuration)
    }
    
    /// MARK: functions to load fixtures
    func loadBasalRateScheduleFixture(_ name: String) -> BasalRateSchedule {
       let fixture: [JSONDictionary] = loadFixture(name)

       let items = fixture.map {
           return RepeatingScheduleValue(startTime: TimeInterval(minutes: $0["minutes"] as! Double), value: $0["rate"] as! Double)
       }

       return BasalRateSchedule(dailyItems: items)!
    }
    
    func loadGlucoseEffect(_ name: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(name)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func testDosingFromEffectsVeryNegative() {
        let expectedRetrospectiveEffect = loadGlucoseEffect("retrospective_output")
        let predictedGlucoseOutput = loadGlucoseEffect("predicted_glucose_very_negative")

        let latestGlucose = StoredGlucoseSample(
            sample: HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
                quantity: HKQuantity(unit: HKUnit.milligramsPerDeciliter, doubleValue: 80.0),
                start: dateFormatter.date(from: "2015-10-25T19:30:00")!,
                end: dateFormatter.date(from: "2015-10-25T19:30:00")!
            )
        )
        
        var glucoseMomentumEffect: [GlucoseEffect]!
        glucoseStore.getRecentMomentumEffect { (effects) -> Void in
            glucoseMomentumEffect = effects
        }
        
        var insulinEffect: [GlucoseEffect]!
        // The dates passed into the mock getGlucoseEffects don't matter
        doseStore.getGlucoseEffects(start: Date(), end: nil, basalDosingEnd: Date()) { (result) -> Void in
            switch result {
            case .failure:
                XCTFail("Mock should always return success")
            case .success(let effects):
                insulinEffect = effects
            }
        }
        
        var insulinCounteractionEffects: [GlucoseEffectVelocity] = []
        // The date & effects passed into the mock getCounteractionEffects doesn't matter
        glucoseStore.getCounteractionEffects(start: Date(), end: nil, to: insulinEffect) { (velocities) in
            insulinCounteractionEffects.append(contentsOf: velocities)
        }
        
        var carbEffect: [GlucoseEffect]!
        carbStore.getGlucoseEffects(start: Date(), end: nil, effectVelocities: insulinCounteractionEffects) { (result) -> Void in
            switch result {
            case .failure:
                XCTFail("Mock should always return success")
            case .success(let (_, effects)):
                carbEffect = effects
            }
        }
        
        let retrospectiveGlucoseDiscrepancies = insulinCounteractionEffects.subtracting(carbEffect, withUniformInterval: TimeInterval(minutes: 5))
        let retrospectiveGlucoseDiscrepanciesSummed = retrospectiveGlucoseDiscrepancies.combinedSums(of: retrospectiveCorrectionGroupingInterval * retrospectiveCorrectionGroupingIntervalMultiplier)
        
        let retrospectiveGlucoseEffect = retrospectiveCorrection.computeEffect(
            startingAt: latestGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
            recencyInterval: inputDataRecencyInterval,
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            basalRateSchedule: basalRateSchedule,
            glucoseCorrectionRangeSchedule: glucoseTargetRangeSchedule,
            retrospectiveCorrectionGroupingInterval: retrospectiveCorrectionGroupingInterval
        )
        
        for (expected, calculated) in zip(expectedRetrospectiveEffect, retrospectiveGlucoseEffect) {
            XCTAssertEqual(expected, calculated)
        }
        
        let predictedGlucose = LoopMath.predictGlucose(startingAt: latestGlucose, effects: carbEffect, insulinEffect, glucoseMomentumEffect, retrospectiveGlucoseEffect)

        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter))
        }
        
        let dose = predictedGlucose.recommendedTempBasal(
            to: glucoseTargetRangeSchedule,
            at: predictedGlucose.first!.startDate,
            suspendThreshold: suspendThreshold.quantity,
            sensitivity: insulinSensitivitySchedule,
            model: exponentialInsulinModel, //walshInsulinModel,
            basalRates: basalRateSchedule,
            maxBasalRate: maxBasalRate,
            lastTempBasal: nil
        )
        
        // Assert it's a suspend
        XCTAssertEqual(0, dose!.unitsPerHour)
        XCTAssertEqual(TimeInterval(minutes: 30), dose!.duration)
    }

    func testDosingWithoutRetrospectiveEffect() {
        let predictedGlucoseOutput = loadGlucoseEffect("predicted_glucose_without_retrospective")

        let latestGlucose = StoredGlucoseSample(
            sample: HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
                quantity: HKQuantity(unit: HKUnit.milligramsPerDeciliter, doubleValue: 80.0),
                start: dateFormatter.date(from: "2015-10-25T19:30:00")!,
                end: dateFormatter.date(from: "2015-10-25T19:30:00")!
            )
        )
        
        var glucoseMomentumEffect: [GlucoseEffect]!
        glucoseStore.getRecentMomentumEffect { (effects) -> Void in
            glucoseMomentumEffect = effects
        }
        
        var insulinEffect: [GlucoseEffect]!
        // The dates passed into the mock getGlucoseEffects don't matter
        doseStore.getGlucoseEffects(start: Date(), end: nil, basalDosingEnd: Date()) { (result) -> Void in
            switch result {
            case .failure:
                XCTFail("Mock should always return success")
            case .success(let effects):
                insulinEffect = effects
            }
        }
        
        var insulinCounteractionEffects: [GlucoseEffectVelocity] = []
        // The date passed into the mock getCounteractionEffects doesn't matter
        glucoseStore.getCounteractionEffects(start: Date(), end: nil, to: insulinEffect) { (velocities) in
            insulinCounteractionEffects.append(contentsOf: velocities)
        }
        
        var carbEffect: [GlucoseEffect]!
        carbStore.getGlucoseEffects(start: Date(), end: nil, effectVelocities: insulinCounteractionEffects) { (result) -> Void in
            switch result {
            case .failure:
                XCTFail("Mock should always return success")
            case .success(let (_, effects)):
                carbEffect = effects
            }
        }
        
        let predictedGlucose = LoopMath.predictGlucose(startingAt: latestGlucose, effects: carbEffect, insulinEffect, glucoseMomentumEffect)

        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter))
        }
        
        let dose = predictedGlucose.recommendedTempBasal(
            to: glucoseTargetRangeSchedule,
            at: predictedGlucose.first!.startDate,
            suspendThreshold: suspendThreshold.quantity,
            sensitivity: insulinSensitivitySchedule,
            model: exponentialInsulinModel, //walshInsulinModel,
            basalRates: basalRateSchedule,
            maxBasalRate: maxBasalRate,
            lastTempBasal: nil
        )
        
        // Assert that we shouldn't set a temp
        XCTAssertNil(dose)
    }
}

extension LoopDataManagerDosingTests {
    public var bundle: Bundle {
        return Bundle(for: type(of: self))
    }

    public func loadFixture<T>(_ resourceName: String) -> T {
        let path = bundle.path(forResource: resourceName, ofType: "json")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)), options: []) as! T
    }
}
