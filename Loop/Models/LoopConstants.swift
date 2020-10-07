//
//  LoopConstants.swift
//  Loop
//
//  Created by Pete Schwamb on 10/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

struct LoopConstants {
    
    // Input field bounds
    
    static let maxCarbEntryQuantity = HKQuantity(unit: .gram(), doubleValue: 250)
    
    static let validManualGlucoseEntryRange = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 10)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 600)

    
    // MARK - Display settings

    static let minimumChartWidthPerHour: CGFloat = 50

    static let statusChartMinimumHistoryDisplay: TimeInterval = .hours(1)

    static let defaultGlucoseDisplayRange = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 60)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200)
    
    
    // Compile time configuration
   
    static let defaultCarbAbsorptionTimes: CarbStore.DefaultAbsorptionTimes = (fast: .minutes(30), medium: .hours(3), slow: .hours(5))
    
    static let retrospectiveCorrectionEnabled = true

    /// The interval over which to aggregate changes in glucose for retrospective correction
    static let retrospectiveCorrectionGroupingInterval = TimeInterval(minutes: 30)

    /// The amount of time since a given date that input data should be considered valid
    static let inputDataRecencyInterval = TimeInterval(minutes: 15)
    
    /// Loop completion aging category limits
    static let completionFreshLimit = TimeInterval(minutes: 6)
    static let completionAgingLimit = TimeInterval(minutes: 16)
    static let completionStaleLimit = TimeInterval(hours: 12)
 
    static let batteryReplacementDetectionThreshold = 0.5
 
    static let defaultWatchCarbPickerValue = 15 // grams
    
    static let defaultWatchBolusPickerValue = 1.0 // %
}
