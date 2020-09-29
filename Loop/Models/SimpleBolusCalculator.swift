//
//  SimpleBolusCalculator.swift
//  Loop
//
//  Created by Pete Schwamb on 9/28/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopCore
import HealthKit
import LoopKit

struct SimpleBolusCalculator {
    
    enum BolusInput {
        case meal(carbs: HKQuantity)
        case correction(glucose: GlucoseValue)
        case mealAndCorrection(carbs: HKQuantity, glucose: GlucoseValue)
    }
    
    public static func recommendedInsulin(mealCarbs: HKQuantity?, manualGlucose: HKQuantity?, activeInsulin: HKQuantity, carbRatioSchedule: CarbRatioSchedule, correctionRangeSchedule: GlucoseRangeSchedule, sensitivitySchedule: InsulinSensitivitySchedule, at date: Date = Date()) -> HKQuantity {
        var recommendedBolus: Double = 0
        
        if let mealCarbs = mealCarbs {
            let carbRatio = carbRatioSchedule.quantity(at: date)
            recommendedBolus += mealCarbs.doubleValue(for: .gram()) / carbRatio.doubleValue(for: .gram())
        }
        
        if let manualGlucose = manualGlucose {
            let sensitivity = sensitivitySchedule.quantity(at: date).doubleValue(for: .milligramsPerDeciliter)
            let correctionRange = correctionRangeSchedule.quantityRange(at: date)
            if (!correctionRange.contains(manualGlucose)) {
                let correctionTarget = correctionRange.averageValue(for: .milligramsPerDeciliter)
                recommendedBolus +=  (manualGlucose.doubleValue(for: .milligramsPerDeciliter) - correctionTarget) / sensitivity
            }
        }
        
        recommendedBolus -= activeInsulin.doubleValue(for: .internationalUnit())
        
        // No negative recommendation
        recommendedBolus = max(0, recommendedBolus)
        
        return HKQuantity(unit: .internationalUnit(), doubleValue: recommendedBolus)
    }
}
