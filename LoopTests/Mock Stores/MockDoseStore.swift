//
//  MockDoseStore.swift
//  LoopTests
//
//  Created by Anna Quinlan on 8/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
@testable import Loop

class MockDoseStore: DoseStoreProtocol {
    func getDoses(start: Date?, end: Date?) async throws -> [LoopKit.DoseEntry] {
        return doseHistory ?? [] + addedDoses
    }

    var addedDoses: [DoseEntry] = []

    func addDoses(_ doses: [DoseEntry], from device: HKDevice?) async throws {
        addedDoses = doses
    }
    
    var lastReservoirValue: LoopKit.ReservoirValue?

    func getTotalUnitsDelivered(since startDate: Date) async throws -> LoopKit.InsulinValue {
        return InsulinValue(startDate: lastAddedPumpData, value: 0)
    }
    
    var lastAddedPumpData: Date
    
    var doseHistory: [DoseEntry]?
    
    init(for scenario: DosingTestScenario = .flatAndStable) {
        self.scenario = scenario // The store returns different effect values based on the scenario
        self.lastAddedPumpData = scenario.currentDate
        self.doseHistory = loadHistoricDoses(scenario: scenario)
    }
    
    static let dateFormatter = ISO8601DateFormatter.localTimeDate()
    
    var scenario: DosingTestScenario
}

extension MockDoseStore {
    public var bundle: Bundle {
        return Bundle(for: type(of: self))
    }

    public func loadFixture<T>(_ resourceName: String) -> T {
        let path = bundle.path(forResource: resourceName, ofType: "json")!
        return try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)), options: []) as! T
    }
    
    var fixtureToLoad: String {
        switch scenario {
        case .liveCapture:
            fatalError("live capture scenario computes effects from doses, does not used pre-canned effects")
        case .flatAndStable:
            return "flat_and_stable_insulin_effect"
        case .highAndStable:
            return "high_and_stable_insulin_effect"
        case .highAndRisingWithCOB:
            return "high_and_rising_with_cob_insulin_effect"
        case .lowAndFallingWithCOB:
            return "low_and_falling_insulin_effect"
        case .lowWithLowTreatment:
            return "low_with_low_treatment_insulin_effect"
        case .highAndFalling:
            return "high_and_falling_insulin_effect"
        }
    }

    public func loadHistoricDoses(scenario: DosingTestScenario) -> [DoseEntry]? {
        if let url = bundle.url(forResource: scenario.fixturePrefix + "doses", withExtension: "json"),
           let data = try? Data(contentsOf: url)
        {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode([DoseEntry].self, from: data)
        } else {
            return nil
        }
    }

}
