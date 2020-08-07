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
    var latestGlucose: GlucoseSampleValue?
    
    var preferredUnit: HKUnit?
    
    var sampleType: HKSampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
    
    var delegate: GlucoseStoreDelegate?
    
    var managedDataInterval: TimeInterval?
    
    var authorizationRequired: Bool = false
    
    var sharingDenied: Bool = false
    
    var healthStore: HKHealthStore = HKHealthStoreMock()
    
    func authorize(toShare: Bool, _ completion: @escaping (HealthKitSampleStoreResult<Bool>) -> Void) {
        completion(.success(true))
    }
    
    func addGlucose(_ glucose: NewGlucoseSample, completion: @escaping (GlucoseStoreResult<GlucoseValue>) -> Void) {
        completion(.failure(DoseStore.DoseStoreError.configurationError)) // ANNA TODO: add this error to glucose store?
    }
    
    func addGlucose(_ values: [NewGlucoseSample], completion: @escaping (GlucoseStoreResult<[GlucoseValue]>) -> Void) {
        completion(.failure(DoseStore.DoseStoreError.configurationError)) // ANNA TODO: add this error to glucose store?
    }
    
    func getCachedGlucoseSamples(start: Date, end: Date?, completion: @escaping ([StoredGlucoseSample]) -> Void) {
        completion([])
    }
    
    func generateDiagnosticReport(_ completion: @escaping (String) -> Void) {
        completion("")
    }
    
    func purgeGlucoseSamples(matchingCachePredicate cachePredicate: NSPredicate?, healthKitPredicate: NSPredicate, completion: @escaping (Bool, Int, Error?) -> Void) {
        completion(false, 0, DoseStore.DoseStoreError.configurationError) // ANNA TODO: add this error to glucose store?
    }
    
    func executeGlucoseQuery(fromQueryAnchor queryAnchor: GlucoseStore.QueryAnchor?, limit: Int, completion: @escaping (GlucoseStore.GlucoseQueryResult) -> Void) {
        completion(.failure( DoseStore.DoseStoreError.configurationError)) // ANNA TODO: add this error to glucose store?))
    }
    
    func counteractionEffects<Sample>(for samples: [Sample], to effects: [GlucoseEffect]) -> [GlucoseEffectVelocity] where Sample : GlucoseSampleValue {
        return [] // TODO: check if we'll ever want to test this
    }
    
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

