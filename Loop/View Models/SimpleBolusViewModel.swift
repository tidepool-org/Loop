//
//  SimpleBolusViewModel.swift
//  Loop
//
//  Created by Pete Schwamb on 9/29/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

class SimpleBolusViewModel: ObservableObject {
    @Published var recommendedBolus: String = "0"
    
    @Published var enteredCarbAmount: String = "" {
        didSet {
            updateRecommendation()
        }
    }

    @Published var enteredGlucoseAmount: String = "" {
        didSet {
            updateRecommendation()
        }
    }

    @Published var enteredBolusAmount: String
    
    private var recommendation: Double? = nil {
        didSet {
            if let recommendation = recommendation, let recommendationString = Self.doseAmountFormatter.string(from: recommendation) {
                recommendedBolus = recommendationString
                enteredBolusAmount = recommendationString
            } else {
                recommendedBolus = NSLocalizedString("-", comment: "String denoting lack of a recommended bolus amount in the simple bolus calculator")
                enteredBolusAmount = Self.doseAmountFormatter.string(from: 0.0)!
            }
        }
    }

    private static let doseAmountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    private static let carbAmountFormatter: NumberFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.setPreferredNumberFormatter(for: .gram())
        return quantityFormatter.numberFormatter
    }()

    func updateRecommendation() {
        var carbs: HKQuantity?
        var glucose: HKQuantity?
        if let enteredCarbAmount = Self.carbAmountFormatter.number(from: enteredCarbAmount)?.doubleValue {
            carbs = HKQuantity(unit: .gram(), doubleValue: enteredCarbAmount)
        }
        if let enteredGlucoseAmount = glucoseAmountFormatter.number(from: enteredGlucoseAmount)?.doubleValue {
            glucose = HKQuantity(unit: glucoseUnit, doubleValue: enteredGlucoseAmount)
        }
        
        if carbs != nil || glucose != nil {
            recommendation = recommendationProvider((carbs: carbs, glucose: glucose))?.doubleValue(for: .internationalUnit())
        } else {
            recommendation = nil
        }
    }
    
    var carbPlaceholder: String {
        Self.carbAmountFormatter.string(from: 0.0)!
    }

    var recommendationProvider: ((carbs: HKQuantity?, glucose: HKQuantity?)) -> HKQuantity?
    var glucoseUnit: HKUnit
    
    private let glucoseAmountFormatter: NumberFormatter
    
    init(glucoseUnit: HKUnit, recommendationProvider: @escaping ((carbs: HKQuantity?, glucose: HKQuantity?)) -> HKQuantity?) {
        self.recommendationProvider = recommendationProvider
        self.glucoseUnit = glucoseUnit
        let glucoseQuantityFormatter = QuantityFormatter()
        glucoseQuantityFormatter.setPreferredNumberFormatter(for: glucoseUnit)
        glucoseAmountFormatter = glucoseQuantityFormatter.numberFormatter
        enteredBolusAmount = Self.doseAmountFormatter.string(from: 0.0)!
        updateRecommendation()
    }
}
