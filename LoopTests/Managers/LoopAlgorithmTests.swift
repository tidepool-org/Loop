//
//  LoopAlgorithmTests.swift
//  LoopTests
//
//  Created by Pete Schwamb on 8/17/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit
import LoopCore
import HealthKit

final class LoopAlgorithmTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

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


extension LoopAlgorithmInput<StoredCarbEntry, StoredGlucoseSample, DoseEntry> {
    static func mock(for date: Date, glucose: [Double] = [100, 120, 140, 160]) -> LoopAlgorithmInput {

        func d(_ interval: TimeInterval) -> Date {
            return date.addingTimeInterval(interval)
        }

        var input = LoopAlgorithmInput<StoredCarbEntry, StoredGlucoseSample, DoseEntry>(
            predictionStart: date,
            glucoseHistory: [],
            doses: [],
            carbEntries: [],
            basal: [],
            sensitivity: [],
            carbRatio: [],
            target: [],
            suspendThreshold: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 65),
            maxBolus: 6,
            maxBasalRate: 8,
            recommendationInsulinType: .novolog,
            recommendationType: .automaticBolus
        )

        for (idx, value) in glucose.enumerated() {
            let entry = StoredGlucoseSample(startDate: d(.minutes(Double(-(glucose.count - idx)*5)) + .minutes(1)), quantity: .glucose(value: value))
            input.glucoseHistory.append(entry)
        }

        input.doses = [
            DoseEntry(type: .bolus, startDate: d(.minutes(-3)), value: 1.0, unit: .units)
        ]

        input.carbEntries = [
            StoredCarbEntry(startDate: d(.minutes(-4)), quantity: .carbs(value: 20))
        ]

        let forecastEndTime = date.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration).dateCeiledToTimeInterval(.minutes(GlucoseMath.defaultDelta))
        let dosesStart = date.addingTimeInterval(-(CarbMath.maximumAbsorptionTimeInterval + InsulinMath.defaultInsulinActivityDuration))
        let carbsStart = date.addingTimeInterval(-CarbMath.maximumAbsorptionTimeInterval)


        let basalRateSchedule = BasalRateSchedule(
            dailyItems: [
                RepeatingScheduleValue(startTime: 0, value: 1),
            ],
            timeZone: .utcTimeZone
        )!
        input.basal = basalRateSchedule.between(start: dosesStart, end: date)

        let insulinSensitivitySchedule = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0, value: 45),
                RepeatingScheduleValue(startTime: 32400, value: 55)
            ],
            timeZone: .utcTimeZone
        )!
        input.sensitivity = insulinSensitivitySchedule.quantitiesBetween(start: dosesStart, end: forecastEndTime)

        let carbRatioSchedule = CarbRatioSchedule(
            unit: .gram(),
            dailyItems: [
                RepeatingScheduleValue(startTime: 0.0, value: 10.0),
            ],
            timeZone: .utcTimeZone
        )!
        input.carbRatio = carbRatioSchedule.between(start: carbsStart, end: date)

        let targetSchedule = GlucoseRangeSchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 100, maxValue: 110)),
            ],
            timeZone: .utcTimeZone
        )!
        input.target = targetSchedule.quantityBetween(start: date, end: forecastEndTime)
        return input
    }
}

