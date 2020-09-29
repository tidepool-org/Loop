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
            if let enteredCarbs = Self.carbAmountFormatter.number(from: enteredCarbAmount)?.doubleValue, enteredCarbs > 0 {
                carbs = HKQuantity(unit: .gram(), doubleValue: enteredCarbs)
            } else {
                carbs = nil
            }
            updateRecommendation()
        }
    }

    @Published var enteredGlucoseAmount: String = "" {
        didSet {
            if let enteredGlucose = glucoseAmountFormatter.number(from: enteredGlucoseAmount)?.doubleValue {
                glucose = HKQuantity(unit: glucoseUnit, doubleValue: enteredGlucose)
            } else {
                glucose = nil
            }
            updateRecommendation()
        }
    }

    @Published var enteredBolusAmount: String {
        didSet {
            if let enteredBolusAmount = Self.doseAmountFormatter.number(from: enteredBolusAmount)?.doubleValue, enteredBolusAmount > 0 {
                bolus = HKQuantity(unit: .internationalUnit(), doubleValue: enteredBolusAmount)
            } else {
                bolus = nil
            }
        }
    }
    
    private var carbs: HKQuantity? = nil
    private var glucose: HKQuantity? = nil
    private var bolus: HKQuantity? = nil

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

    enum ActionButtonAction {
        case saveWithoutBolusing
        case saveAndDeliver
        case enterBolus
        case deliver
    }
    
    var hasDataToSave: Bool {
        return glucose != nil || carbs != nil
    }
    
    var hasBolusEntryReadyToDeliver: Bool {
        return bolus != nil
    }
    
    var actionButtonAction: ActionButtonAction {
        switch (hasDataToSave, hasBolusEntryReadyToDeliver) {
        case (true, true): return .saveAndDeliver
        case (true, false): return .saveWithoutBolusing
        case (false, true): return .deliver
        case (false, false): return .enterBolus
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
    
    func updateRecommendation() {
        if carbs != nil || glucose != nil {
            recommendation = recommendationProvider((carbs: carbs, glucose: glucose))?.doubleValue(for: .internationalUnit())
        } else {
            recommendation = nil
        }
    }
    

}
