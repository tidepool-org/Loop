//
//  MockInsulinDeliveryStore.swift
//  LoopTests
//
//  Created by Anna Quinlan on 8/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit

class MockInsulinDeliveryStore: InsulinDeliveryStoreProtocol {
    var sampleType: HKSampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.insulinDelivery)!
    
    var authorizationRequired: Bool = false
    
    var sharingDenied: Bool = false
    
    func authorize(toShare: Bool, _ completion: @escaping (HealthKitSampleStoreResult<Bool>) -> Void) {
        completion(.success(true))
    }
    
    func generateDiagnosticReport(_ completion: @escaping (String) -> Void) {
        completion("")
    }
}


