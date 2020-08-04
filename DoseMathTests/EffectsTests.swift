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
    
    func getGlucoseEffects(start: Date, end: Date?, basalDosingEnd: Date?, completion: @escaping (_ result: DoseStoreResult<[GlucoseEffect]>) -> Void) {
        let fixture: [JSONDictionary] = loadFixture("effect_from_history_output")
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)

        return completion(.success(fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
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

class EffectsTests: XCTestCase {
    var doseStore: MockDoseStore!
    private let fixtureTimeZone = TimeZone(secondsFromGMT: -0 * 60 * 60)!
    
    override func setUp() {
        super.setUp()
        doseStore = MockDoseStore()
    }

    func loadGlucoseValueFixture(_ resourceName: String) -> [GlucoseFixtureValue] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)

        return fixture.map {
            return GlucoseFixtureValue(
                startDate: dateFormatter.date(from: $0["date"] as! String)!,
                quantity: HKQuantity(unit: HKUnit.milligramsPerDeciliter, doubleValue: $0["amount"] as! Double)
            )
        }
    }
    
    func loadGlucoseEffectFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }
    
    func loadDoseFixture(_ resourceName: String) -> [DoseEntry] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)

        return fixture.compactMap {
            guard let unit = DoseUnit(rawValue: $0["unit"] as! String),
                  let pumpType = PumpEventType(rawValue: $0["type"] as! String),
                  let type = DoseType(pumpEventType: pumpType)
            else {
                return nil
            }
            
            var scheduledBasalRate: HKQuantity? = nil
            if let scheduled = $0["scheduled"] as? Double {
                scheduledBasalRate = HKQuantity(unit: unit.unit, doubleValue: scheduled)
            }

            return DoseEntry(
                type: type,
                startDate: dateFormatter.date(from: $0["start_at"] as! String)!,
                endDate: dateFormatter.date(from: $0["end_at"] as! String)!,
                value: $0["amount"] as! Double,
                unit: unit,
                description: $0["description"] as? String,
                syncIdentifier: $0["raw"] as? String,
                scheduledBasalRate: scheduledBasalRate
            )
        }
    }
    
    
    
}
