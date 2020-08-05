//
//  EffectsTests.swift
//  DoseMathTests
//
//  Created by Anna Quinlan on 8/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit
@testable import Loop

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

class MockDoseStore: DoseStoreTestingProtocol {
    private let fixtureTimeZone = TimeZone(secondsFromGMT: -0 * 60 * 60)!
    
    func getGlucoseEffects(start: Date, end: Date? = nil, basalDosingEnd: Date? = Date(), completion: @escaping (_ result: DoseStoreResult<[GlucoseEffect]>) -> Void) {
        let fixture: [JSONDictionary] = loadFixture("effect_from_history_output")
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)

        return completion(.success(fixture.map {
            return GlucoseEffect(
                startDate: dateFormatter.date(from: $0["date"] as! String)!,
                quantity: HKQuantity(
                    unit: HKUnit(from: $0["unit"] as! String),
                    doubleValue: $0["amount"] as! Double
                )
            )
        }))
    }
}

extension MockDoseStore {
    public var bundle: Bundle {
        return Bundle(for: type(of: self))
    }

    public func loadFixture<T>(_ resourceName: String) -> T {
        let path = bundle.path(forResource: resourceName, ofType: "json")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)), options: []) as! T
    }
}

class MockGlucoseStore: GlucoseStoreTestingProtocol {
    func getRecentMomentumEffect(_ completion: @escaping (_ effects: [GlucoseEffect]) -> Void) {
        let fixture: [JSONDictionary] = loadFixture("momentum_effect_bouncing_glucose_output")
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return completion(fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue: $0["amount"] as! Double))
            }
        )
    }
    
    func getCachedGlucoseSamples(start: Date, end: Date? = nil, completion: @escaping (_ samples: [StoredGlucoseSample]) -> Void) {
        let fixture: [JSONDictionary] = loadFixture("momentum_effect_bouncing_glucose_input")
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return completion(fixture.map {
            return StoredGlucoseSample(sample: HKQuantitySample(
                type: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
                quantity: HKQuantity(unit: HKUnit.milligramsPerDeciliter, doubleValue: $0["amount"] as! Double),
                start: dateFormatter.date(from: $0["date"] as! String)!,
                end: dateFormatter.date(from: $0["date"] as! String)!)
            )
        })
    }
    
    func getCounteractionEffects(start: Date, end: Date?, to effects: [GlucoseEffect], _ completion: @escaping (_ effects: [GlucoseEffectVelocity]) -> Void) {
        getCachedGlucoseSamples(start: start, end: end) { (samples) in
            completion(self.counteractionEffects(for: samples, to: effects))
        }
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
        let fixture: [JSONDictionary] = loadFixture("dynamic_glucose_effect_partially_observed_output")
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

class EffectsTests: XCTestCase {
    static let retrospectiveCorrectionEffectDuration = TimeInterval(hours: 1)
    
    var doseStore: DoseStoreTestingProtocol!
    var glucoseStore: GlucoseStoreTestingProtocol!
    var carbStore: CarbStoreTestingProtocol!
    var retrospectiveCorrection: RetrospectiveCorrection!
    
    override func setUp() {
        super.setUp()
        doseStore = MockDoseStore()
        glucoseStore = MockGlucoseStore()
        carbStore = MockCarbStore()
        retrospectiveCorrection = StandardRetrospectiveCorrection(effectDuration: EffectsTests.retrospectiveCorrectionEffectDuration)
    }
    
    func testRetrospectiveCorrectionFromEffects() {
        var glucoseMomentumEffect: [GlucoseEffect]!
        glucoseStore.getRecentMomentumEffect { (effects) -> Void in
            glucoseMomentumEffect = effects
        }
        
        var insulinEffect: [GlucoseEffect]
        // The date passed into the mock getGlucoseEffects doesn't matter
        doseStore.getGlucoseEffects(start: Date()) { (result) -> Void in
            switch result {
            case .failure(let error):
                XCTFail("Mock should always return success")
            case .success(let effects):
                insulinEffect = effects
            }
        }
        
        var insulinCounteractionEffects: [GlucoseEffectVelocity]!
        // The date passed into the mock getCounteractionEffects doesn't matter
        glucoseStore.getCounteractionEffects(start: Date(), to: insulinEffect) { (velocities) in
            insulinCounteractionEffects.append(contentsOf: velocities)
            updateGroup.leave()
        }
    
//    retrospectiveGlucoseEffect = retrospectiveCorrection.computeEffect(
//        startingAt: glucose,
//        retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
//        recencyInterval: settings.inputDataRecencyInterval,
//        insulinSensitivitySchedule: insulinSensitivitySchedule,
//        basalRateSchedule: basalRateSchedule,
//        glucoseCorrectionRangeSchedule: settings.glucoseTargetRangeSchedule,
//        retrospectiveCorrectionGroupingInterval: settings.retrospectiveCorrectionGroupingInterval
//    )
    }
}
