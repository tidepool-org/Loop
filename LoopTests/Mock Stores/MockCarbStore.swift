//
//  MockCarbStore.swift
//  LoopTests
//
//  Created by Anna Quinlan on 8/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
@testable import Loop

class MockCarbStore: CarbStoreProtocol {
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
