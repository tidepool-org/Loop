//
//  DeviceDataManager+SimpleBolusViewModelDelegate.swift
//  Loop
//
//  Created by Pete Schwamb on 9/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopCore
import LoopKit

extension DeviceDataManager: SimpleBolusViewModelDelegate {
    func addGlucose(_ samples: [NewGlucoseSample], completion: @escaping (Error?) -> Void) {
        loopManager.addGlucose(samples) { (result) in
            switch result {
            case .failure(let error):
                completion(error)
            case .success:
                completion(nil)
            }
        }
    }
    
    func addCarbEntry(_ carbEntry: NewCarbEntry, completion: @escaping (Error?) -> Void) {
        loopManager.addCarbEntry(carbEntry) { (result) in
            switch result {
            case .failure(let error):
                completion(error)
            case .success:
                completion(nil)
            }
        }
    }
    
    func enactBolus(units: Double, at startDate: Date) {
        enactBolus(units: units, at: startDate) { (_) in }
    }
    
    func insulinOnBoard(at date: Date, completion: @escaping (DoseStoreResult<InsulinValue>) -> Void) {
        doseStore.insulinOnBoard(at: date, completion: completion)
    }
    
    func computeSimpleBolusRecommendation(carbs: HKQuantity?, glucose: HKQuantity?) -> HKQuantity? {
        return loopManager.generateSimpleBolusRecommendation(carbs: carbs, glucose: glucose)
    }
    
    var preferredGlucoseUnit: HKUnit {
        return glucoseStore.preferredUnit!
    }
    
    var maximumBolus: Double {
        return loopManager.settings.maximumBolus!
    }
}
