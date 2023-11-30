//
//  MockGlucoseStore.swift
//  LoopTests
//
//  Created by Anna Quinlan on 8/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
@testable import Loop

class MockGlucoseStore: GlucoseStoreProtocol {

    init(for scenario: DosingTestScenario = .flatAndStable) {
        self.scenario = scenario // The store returns different effect values based on the scenario
        storedGlucose = loadHistoricGlucose(scenario: scenario)
    }

    func getGlucoseSamples(start: Date?, end: Date?) async throws -> [LoopKit.StoredGlucoseSample] {
        [latestGlucose as! StoredGlucoseSample]
    }

    func addGlucoseSamples(_ samples: [LoopKit.NewGlucoseSample]) async throws -> [LoopKit.StoredGlucoseSample] {
        // Using the dose store error because we don't need to create GlucoseStore errors just for the mock store
        throw DoseStore.DoseStoreError.configurationError
    }

    let dateFormatter = ISO8601DateFormatter.localTimeDate()
    
    var scenario: DosingTestScenario

    var storedGlucose: [StoredGlucoseSample]?
    
    var latestGlucose: GlucoseSampleValue? {
        if let storedGlucose {
            return storedGlucose.last
        } else {
            return StoredGlucoseSample(
                sample: HKQuantitySample(
                    type: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
                    quantity: HKQuantity(unit: HKUnit.milligramsPerDeciliter, doubleValue: latestGlucoseValue),
                    start: glucoseStartDate,
                    end: glucoseStartDate
                )
            )
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

    public func loadHistoricGlucose(scenario: DosingTestScenario) -> [StoredGlucoseSample]? {
        if let url = bundle.url(forResource: scenario.fixturePrefix + "historic_glucose", withExtension: "json"),
           let data = try? Data(contentsOf: url)
        {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode([StoredGlucoseSample].self, from: data)
        } else {
            return nil
        }
    }
    
    var glucoseStartDate: Date {
        switch scenario {
        case .liveCapture:
            fatalError("live capture scenario uses actual glucose input data")
        case .flatAndStable:
            return dateFormatter.date(from: "2020-08-11T20:45:02")!
        case .highAndStable:
            return dateFormatter.date(from: "2020-08-12T12:39:22")!
        case .highAndRisingWithCOB:
            return dateFormatter.date(from: "2020-08-11T21:48:17")!
        case .lowAndFallingWithCOB:
            return dateFormatter.date(from: "2020-08-11T22:06:06")!
        case .lowWithLowTreatment:
            return dateFormatter.date(from: "2020-08-11T22:23:55")!
        case .highAndFalling:
            return dateFormatter.date(from: "2020-08-11T22:59:45")!
        }
    }
    
    var latestGlucoseValue: Double {
        switch scenario {
        case .liveCapture:
            fatalError("live capture scenario uses actual glucose input data")
        case .flatAndStable:
            return 123.42849966275706
        case .highAndStable:
            return 200.0
        case .highAndRisingWithCOB:
            return 129.93174411197853
        case .lowAndFallingWithCOB:
            return 75.10768374646841
        case .lowWithLowTreatment:
            return 81.22399763523448
        case .highAndFalling:
            return 200.0
        }
    }
}

