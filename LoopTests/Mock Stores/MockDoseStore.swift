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
    var basalProfileApplyingOverrideHistory: BasalRateSchedule?
    
    
    var insulinDeliveryStore: InsulinDeliveryStore = InsulinDeliveryStore(
        healthStore: HKHealthStoreMock(),
        observeHealthKitForCurrentAppOnly: false,
        cacheStore: PersistenceController(directoryURL: URL.init(fileURLWithPath: "")),
        observationEnabled: true,
        test_currentDate: Date() // ANNA TODO: fix this
    )
    
    var delegate: DoseStoreDelegate?
    
    var device: HKDevice?
    
    var pumpRecordsBasalProfileStartEvents: Bool = false
    
    var pumpEventQueryAfterDate: Date = Date() // ANNA TODO: fix this
    
    var basalProfile: BasalRateSchedule?
    
    var insulinModel: InsulinModel?
    
    var insulinSensitivitySchedule: InsulinSensitivitySchedule?
    
    var sampleType: HKSampleType?
    
    var authorizationRequired: Bool = false
    
    var sharingDenied: Bool = false
    
    var lastReservoirValue: ReservoirValue?
    
    var lastAddedPumpData: Date = Date()
    
    func addPumpEvents(_ events: [NewPumpEvent], lastReconciliation: Date?, completion: @escaping (DoseStore.DoseStoreError?) -> Void) {
        completion(nil)
    }
    
    func addReservoirValue(_ unitVolume: Double, at date: Date, completion: @escaping (ReservoirValue?, ReservoirValue?, Bool, DoseStore.DoseStoreError?) -> Void) {
        completion(nil, nil, false, nil)
    }
    
    func insulinOnBoard(at date: Date, completion: @escaping (DoseStoreResult<InsulinValue>) -> Void) {
        completion(.failure(.configurationError))
    }
    
    func generateDiagnosticReport(_ completion: @escaping (String) -> Void) {
        completion("")
    }
    
    func resetPumpData(completion: ((DoseStore.DoseStoreError?) -> Void)?) {
        completion?(.configurationError)
    }
    
    func getInsulinOnBoardValues(start: Date, end: Date?, basalDosingEnd: Date?, completion: @escaping (DoseStoreResult<[InsulinValue]>) -> Void) {
        completion(.failure(.configurationError))
    }
    
    func getNormalizedDoseEntries(start: Date, end: Date?, completion: @escaping (DoseStoreResult<[DoseEntry]>) -> Void) {
        completion(.failure(.configurationError))
    }
    
    func executePumpEventQuery(fromQueryAnchor queryAnchor: DoseStore.QueryAnchor?, limit: Int, completion: @escaping (DoseStore.PumpEventQueryResult) -> Void) {
        completion(.failure(DoseStore.DoseStoreError.configurationError))
    }
    
    func executeDoseQuery(fromQueryAnchor queryAnchor: DoseStore.QueryAnchor?, limit: Int, completion: @escaping (DoseStore.DoseQueryResult) -> Void) {
        completion(.failure(DoseStore.DoseStoreError.configurationError))
    }
    
    func getTotalUnitsDelivered(since startDate: Date, completion: @escaping (DoseStoreResult<InsulinValue>) -> Void) {
        completion(.failure(.configurationError))
    }
    
    private let fixtureTimeZone = TimeZone(secondsFromGMT: -0 * 60 * 60)!
    
    func getGlucoseEffects(start: Date, end: Date? = nil, basalDosingEnd: Date? = Date(), completion: @escaping (_ result: DoseStoreResult<[GlucoseEffect]>) -> Void) {
        let fixture: [JSONDictionary] = loadFixture("insulin_effect")
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
