//
//  GlucoseStore+SimulatedCoreData.swift
//  Loop
//
//  Created by Darin Krauss on 6/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

// MARK: - Simulated Core Data

extension GlucoseStore {
    private var historicalEndDate: Date { Date(timeIntervalSinceNow: -.hours(24)) }

    private var simulatedStartDateInterval: TimeInterval { .minutes(5) }
    private var simulatedValueBase: Double { 110 }
    private var simulatedValueAmplitude: Double { 40 }
    private var simulatedValueIncrement: Double { 2.0 * .pi / 72.0 }    // 6 hour period

    public func generateSimulatedHistoricalGlucoseObjects(completion: @escaping (Error?) -> Void) {
        var startDate = Calendar.current.startOfDay(for: earliestCacheDate)
        let endDate = Calendar.current.startOfDay(for: historicalEndDate)
        var value = 0.0
        var samples = [StoredGlucoseSample]()

        while startDate < endDate {
            samples.append(StoredGlucoseSample.simulated(startDate: startDate, value: simulatedValueBase + simulatedValueAmplitude * sin(value)))
            value += simulatedValueIncrement
            startDate = startDate.addingTimeInterval(simulatedStartDateInterval)
        }

        addGlucoseSamples(samples: samples, completion: completion)
    }

    public func purgeHistoricalGlucoseObjects(completion: @escaping (Error?) -> Void) {
        purgeCachedGlucoseObjects(before: historicalEndDate, completion: completion)
    }
}

fileprivate extension StoredGlucoseSample {
    static func simulated(startDate: Date, value: Double, unit: HKUnit = HKUnit.milligramsPerDeciliter) -> StoredGlucoseSample {
        return StoredGlucoseSample(sampleUUID: UUID(),
                                   syncIdentifier: UUID().uuidString,
                                   syncVersion: 1,
                                   startDate: startDate,
                                   quantity: HKQuantity(unit: unit, doubleValue: value),
                                   isDisplayOnly: false,
                                   provenanceIdentifier: Bundle.main.bundleIdentifier!)
    }
}
