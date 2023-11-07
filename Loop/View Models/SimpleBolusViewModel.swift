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
import LoopKitUI
import os.log
import SwiftUI
import LoopCore
import Intents
import LocalAuthentication

protocol SimpleBolusViewModelDelegate: AnyObject {
    
    func addGlucose(_ samples: [NewGlucoseSample]) async throws -> [StoredGlucoseSample]

    func addCarbEntry(_ carbEntry: NewCarbEntry, replacing replacingEntry: StoredCarbEntry?) async throws -> StoredCarbEntry

    func storeManualBolusDosingDecision(_ bolusDosingDecision: BolusDosingDecision, withDate date: Date)
    
    func enactBolus(units: Double, activationType: BolusActivationType) async throws

    func insulinOnBoard(at date: Date) async -> InsulinValue?

    func computeSimpleBolusRecommendation(at date: Date, mealCarbs: HKQuantity?, manualGlucose: HKQuantity?) -> BolusDosingDecision?

    var displayGlucosePreference: DisplayGlucosePreference { get }
    
    var maximumBolus: Double? { get }

    var suspendThreshold: HKQuantity? { get }
}

class SimpleBolusViewModel: ObservableObject {
    
    var authenticate: AuthenticationChallenge = LocalAuthentication.deviceOwnerCheck

    enum Alert: Int {
        case carbEntryPersistenceFailure
        case manualGlucoseEntryPersistenceFailure
        case infoPopup
    }
    
    @Published var activeAlert: Alert?
    
    enum Notice: Int {
        case carbohydrateEntryTooLarge
        case glucoseBelowRecommendationLimit
        case glucoseBelowSuspendThreshold
        case glucoseOutOfAllowedInputRange
        case glucoseWarning
        case maxBolusExceeded
        case recommendationExceedsMaxBolus
    }

    @Published var activeNotice: Notice?

    var isNoticeVisible: Bool { return activeNotice != nil }    

    @Published var recommendedBolus: String = "–"
    
    @Published var activeInsulin: String?

    @Published var enteredCarbString: String = "" {
        didSet {
            if let enteredCarbs = Self.carbAmountFormatter.number(from: enteredCarbString)?.doubleValue, enteredCarbs > 0 {
                carbQuantity = HKQuantity(unit: .gram(), doubleValue: enteredCarbs)
            } else {
                carbQuantity = nil
            }
            updateRecommendation()
        }
    }
    
    var displayMealEntry: Bool


    // needed to detect change in display glucose unit when returning to the app
    private var cachedDisplayGlucoseUnit: HKUnit

    var manualGlucoseString: String {
        get  {
            if cachedDisplayGlucoseUnit != displayGlucoseUnit {
                cachedDisplayGlucoseUnit = displayGlucoseUnit
                guard let manualGlucoseQuantity = manualGlucoseQuantity else {
                    _manualGlucoseString = ""
                    return _manualGlucoseString
                }
                self._manualGlucoseString = delegate.displayGlucosePreference.format(manualGlucoseQuantity, includeUnit: false)
            }

            return _manualGlucoseString
        }
        set {
            _manualGlucoseString = newValue
        }
    }
    
    private func updateNotice() {

        guard let maxBolus = delegate.maximumBolus, let suspendThreshold = delegate.suspendThreshold else {
            return
        }

        if let carbs = self.carbQuantity {
            guard carbs <= LoopConstants.maxCarbEntryQuantity else {
                activeNotice = .carbohydrateEntryTooLarge
                return
            }
        }
        
        if let bolus = bolus {
            guard bolus.doubleValue(for: .internationalUnit()) <= maxBolus else {
                activeNotice = .maxBolusExceeded
                return
            }
        }

        let isAddingCarbs: Bool
        if let carbQuantity = carbQuantity, carbQuantity.doubleValue(for: .gram()) > 0 {
            isAddingCarbs = true
        } else {
            isAddingCarbs = false
        }
        
        let minRecommendationGlucose =
            isAddingCarbs ?
            LoopConstants.simpleBolusCalculatorMinGlucoseMealBolusRecommendation :
            LoopConstants.simpleBolusCalculatorMinGlucoseBolusRecommendation
        
        switch manualGlucoseQuantity {
        case let .some(g) where !LoopConstants.validManualGlucoseEntryRange.contains(g):
            activeNotice = .glucoseOutOfAllowedInputRange
        case let g? where g < minRecommendationGlucose:
            activeNotice = .glucoseBelowRecommendationLimit
        case let g? where g < LoopConstants.simpleBolusCalculatorGlucoseWarningLimit:
            activeNotice = .glucoseWarning
        case let g? where g < suspendThreshold:
            activeNotice = .glucoseBelowSuspendThreshold
        default:
            if let recommendation = recommendation, recommendation > maxBolus {
                activeNotice = .recommendationExceedsMaxBolus
            } else {
                activeNotice = nil
            }
        }

    }

    @Published private var _manualGlucoseString: String = "" {
        didSet {
            guard let manualGlucoseValue = delegate.displayGlucosePreference.formatter.numberFormatter.number(from: _manualGlucoseString)?.doubleValue
            else {
                manualGlucoseQuantity = nil
                return
            }

            // if needed update manualGlucoseQuantity and related activeNotice
            if manualGlucoseQuantity == nil ||
                _manualGlucoseString != delegate.displayGlucosePreference.format(manualGlucoseQuantity!, includeUnit: false)
            {
                manualGlucoseQuantity = HKQuantity(unit: cachedDisplayGlucoseUnit, doubleValue: manualGlucoseValue)
                updateNotice()
            }
        }
    }

    @Published var enteredBolusString: String {
        didSet {
            if let enteredBolusAmount = Self.doseAmountFormatter.number(from: enteredBolusString)?.doubleValue, enteredBolusAmount > 0 {
                bolus = HKQuantity(unit: .internationalUnit(), doubleValue: enteredBolusAmount)
            } else {
                bolus = nil
            }
            updateNotice()
        }
    }
    
    private var carbQuantity: HKQuantity? = nil

    private var manualGlucoseQuantity: HKQuantity? = nil {
        didSet {
            updateRecommendation()
        }
    }

    private var bolus: HKQuantity? = nil
    
    var bolusRecommended: Bool {
        if let bolus = bolus, bolus.doubleValue(for: .internationalUnit()) > 0 {
            return true
        }
        return false
    }
    
    var displayGlucoseUnit: HKUnit { return delegate.displayGlucosePreference.unit }
    
    var suspendThreshold: HKQuantity? { return delegate.suspendThreshold }

    private var recommendation: Double? = nil {
        didSet {
            if let recommendation = recommendation, let maxBolus = delegate.maximumBolus {
                recommendedBolus = Self.doseAmountFormatter.string(from: recommendation)!
                enteredBolusString = Self.doseAmountFormatter.string(from: min(recommendation, maxBolus))!
            } else {
                recommendedBolus = NSLocalizedString("–", comment: "String denoting lack of a recommended bolus amount in the simple bolus calculator")
                enteredBolusString = Self.doseAmountFormatter.string(from: 0.0)!
            }
        }
    }
    
    private var dosingDecision: BolusDosingDecision?
    
    private var recommendationDate: Date?

    private static let doseAmountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    private static let carbAmountFormatter: NumberFormatter = {
        let quantityFormatter = QuantityFormatter(for: .gram())
        return quantityFormatter.numberFormatter
    }()

    enum ActionButtonAction {
        case saveWithoutBolusing
        case saveAndDeliver
        case enterBolus
        case deliver
    }
    
    var hasDataToSave: Bool {
        return manualGlucoseQuantity != nil || carbQuantity != nil
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
    
    var actionButtonDisabled: Bool {
        switch activeNotice {
        case .glucoseOutOfAllowedInputRange, .maxBolusExceeded, .carbohydrateEntryTooLarge:
            return true
        default:
            return false
        }
    }
    
    var carbPlaceholder: String {
        Self.carbAmountFormatter.string(from: 0.0)!
    }

    private let delegate: SimpleBolusViewModelDelegate
    private let log = OSLog(category: "SimpleBolusViewModel")
    
    private lazy var bolusVolumeFormatter = QuantityFormatter(for: .internationalUnit())

    var maximumBolusAmountString: String {
        guard let maxBolus = delegate.maximumBolus else {
            return ""
        }
        let maxBolusQuantity = HKQuantity(unit: .internationalUnit(), doubleValue: maxBolus)
        return bolusVolumeFormatter.string(from: maxBolusQuantity)!
    }

    init(delegate: SimpleBolusViewModelDelegate, displayMealEntry: Bool) {
        self.delegate = delegate
        self.displayMealEntry = displayMealEntry
        cachedDisplayGlucoseUnit = delegate.displayGlucosePreference.unit
        enteredBolusString = Self.doseAmountFormatter.string(from: 0.0)!
        updateRecommendation()
        dosingDecision = BolusDosingDecision(for: .simpleBolus)
    }
    
    func updateRecommendation() {
        let recommendationDate = Date()
        
        if let carbs = self.carbQuantity {
            guard carbs <= LoopConstants.maxCarbEntryQuantity else {
                recommendation = nil
                return
            }
        }
        
        if let glucose = manualGlucoseQuantity {
            guard LoopConstants.validManualGlucoseEntryRange.contains(glucose) else {
                recommendation = nil
                return
            }
        }
        
        if carbQuantity != nil || manualGlucoseQuantity != nil {
            dosingDecision = delegate.computeSimpleBolusRecommendation(at: recommendationDate, mealCarbs: carbQuantity, manualGlucose: manualGlucoseQuantity)
            if let decision = dosingDecision, let bolusRecommendation = decision.manualBolusRecommendation {
                recommendation = bolusRecommendation.recommendation.amount
            } else {
                recommendation = nil
            }
            
            if let decision = dosingDecision, let insulinOnBoard = decision.insulinOnBoard, insulinOnBoard.value > 0, manualGlucoseQuantity != nil {
                activeInsulin = Self.doseAmountFormatter.string(from: insulinOnBoard.value)
            } else {
                activeInsulin = nil
            }
            self.recommendationDate = recommendationDate
        } else {
            dosingDecision = nil
            recommendation = nil
            activeInsulin = nil
            self.recommendationDate = nil
        }
    }
    
    func saveAndDeliver() async -> Bool {

        let saveDate = Date()

        // Authenticate the bolus before saving anything
        func authenticateIfNeeded() async -> Bool {
            await withCheckedContinuation { continuation in
                if let bolus = bolus, bolus.doubleValue(for: .internationalUnit()) > 0 {
                    let message = String(format: NSLocalizedString("Authenticate to Bolus %@ Units", comment: "The message displayed during a device authentication prompt for bolus specification"), enteredBolusString)
                    authenticate(message) {
                        switch $0 {
                        case .success:
                            continuation.resume(returning: true)
                        case .failure:
                            continuation.resume(returning: false)
                        }
                    }
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
        
        func saveManualGlucose() async -> Bool {
            if let manualGlucoseQuantity = manualGlucoseQuantity {
                let manualGlucoseSample = NewGlucoseSample(date: saveDate,
                                                           quantity: manualGlucoseQuantity,
                                                           condition: nil,  // All manual glucose entries are assumed to have no condition.
                                                           trend: nil,      // All manual glucose entries are assumed to have no trend.
                                                           trendRate: nil,  // All manual glucose entries are assumed to have no trend rate.
                                                           isDisplayOnly: false,
                                                           wasUserEntered: true,
                                                           syncIdentifier: UUID().uuidString)
                do {
                    let storedSamples = try await delegate.addGlucose([manualGlucoseSample])
                    self.dosingDecision?.manualGlucoseSample = storedSamples.first
                    return true
                } catch {
                    self.presentAlert(.manualGlucoseEntryPersistenceFailure)
                    self.log.error("Failed to add manual glucose entry: %{public}@", String(describing: error))
                    return false
                }
            } else {
                return true
            }
        }
        
        func saveCarbs() async -> Bool {
            if let carbs = carbQuantity {
                let interaction = INInteraction(intent: NewCarbEntryIntent(), response: nil)
                do {
                    try await interaction.donate()
                } catch {
                    log.error("Failed to donate intent: %{public}@", String(describing: error))
                }

                let carbEntry = NewCarbEntry(date: saveDate, quantity: carbs, startDate: saveDate, foodType: nil, absorptionTime: nil)
                
                do {
                    self.dosingDecision?.carbEntry = try await delegate.addCarbEntry(carbEntry, replacing: nil)
                    return true
                } catch {
                    self.presentAlert(.carbEntryPersistenceFailure)
                    self.log.error("Failed to add carb entry: %{public}@", String(describing: error))
                    return false
                }
            } else {
                return true
            }
        }

        func enactBolus() {
            if let bolusVolume = bolus?.doubleValue(for: .internationalUnit()), bolusVolume > 0 {
                Task { @MainActor in
                    do {
                        try await delegate.enactBolus(units: bolusVolume, activationType: .activationTypeFor(recommendedAmount: recommendation, bolusAmount: bolusVolume))
                        dosingDecision?.manualBolusRequested = bolusVolume
                    } catch {
                        log.error("Unable to enact bolus: %{public}@", String(describing: error))
                    }
                }
            }
        }
        
        func saveBolusDecision() {
            if let decision = dosingDecision, let recommendationDate = recommendationDate {
                delegate.storeManualBolusDosingDecision(decision, withDate: recommendationDate)
            }
        }
        
        if await authenticateIfNeeded(), await saveManualGlucose(), await saveCarbs() {
            enactBolus()
            saveBolusDecision()
            return true
        } else {
            saveBolusDecision()
            return false
        }
    }
    
    private func presentAlert(_ alert: Alert) {
        dispatchPrecondition(condition: .onQueue(.main))

        // As of iOS 13.6 / Xcode 11.6, swapping out an alert while one is active crashes SwiftUI.
        guard activeAlert == nil else {
            return
        }

        activeAlert = alert
    }
    
    func restoreUserActivityState(_ activity: NSUserActivity) {
        if let entry = activity.newCarbEntry {
            carbQuantity = entry.quantity
        }
    }
}

extension SimpleBolusViewModel.Alert: Identifiable {
    var id: Self { self }
}
