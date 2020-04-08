//
//  CarbAndBolusFlowViewModel.swift
//  WatchApp Extension
//
//  Created by Michael Pangburn on 3/31/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import HealthKit
import WatchKit
import WatchConnectivity
import LoopKit
import LoopCore


final class CarbAndBolusFlowViewModel: ObservableObject {
    // MARK: - Published state
    @Published var isComputingRecommendedBolus = false
    @Published var recommendedBolusAmount: Double?
    @Published var maxBolus: Double

    // MARK: - Other state
    let interactionStartDate = Date()
    private let carbEntrySyncIdentifier = UUID().uuidString
    private var carbEntryUnderConsideration: NewCarbEntry?
    private var contextUpdateObservation: AnyObject?

    // MARK: - Constants
    private static let defaultMaxBolus: Double = 10 // U

    // MARK: - Initialization
    let configuration: CarbAndBolusFlow.Configuration
    private let _presentAlert: (_ title: String, _ message: String) -> Void
    private let _dismiss: () -> Void

    init(
        configuration: CarbAndBolusFlow.Configuration,
        presentAlert: @escaping (_ title: String, _ message: String) -> Void,
        dismiss: @escaping () -> Void
    ) {
        let loopManager = ExtensionDelegate.shared().loopManager
        switch configuration {
        case .carbEntry:
            break
        case .manualBolus:
            self._recommendedBolusAmount = Published(initialValue: loopManager.activeContext?.recommendedBolusDose)
        }

        self._maxBolus = Published(initialValue: loopManager.settings.maximumBolus ?? Self.defaultMaxBolus)
        self.configuration = configuration
        self._presentAlert = presentAlert
        self._dismiss = dismiss

        contextUpdateObservation = NotificationCenter.default.addObserver(
            forName: LoopDataManager.didUpdateContextNotification,
            object: loopManager,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.maxBolus = loopManager.settings.maximumBolus ?? Self.defaultMaxBolus
            switch self.configuration {
            case .carbEntry:
                // If this new context wasn't generated in response to a potential carb entry message,
                // recompute the recommended bolus for the carb entry under consideration.
                let wasContextGeneratedFromPotentialCarbEntryMessage = loopManager.activeContext?.potentialCarbEntry != nil
                if !wasContextGeneratedFromPotentialCarbEntryMessage, let entry = self.carbEntryUnderConsideration {
                    self.recommendBolus(for: entry)
                }
            case .manualBolus:
                if self.recommendedBolusAmount != loopManager.activeContext?.recommendedBolusDose {
                    self.recommendedBolusAmount = loopManager.activeContext?.recommendedBolusDose
                }
            }
        }
    }

    deinit {
        if let observation = contextUpdateObservation {
            NotificationCenter.default.removeObserver(observation)
        }
    }

    func discardCarbEntryUnderConsideration() {
        carbEntryUnderConsideration = nil
        recommendedBolusAmount = nil
    }

    func recommendBolus(forGrams grams: Int, eatenAt carbEntryDate: Date, absorptionTime carbAbsorptionTime: CarbAbsorptionTime) {
        let entry = NewCarbEntry(
            quantity: HKQuantity(unit: .gram(), doubleValue: Double(grams)),
            startDate: carbEntryDate,
            foodType: nil,
            absorptionTime: absorptionTime(for: carbAbsorptionTime),
            syncIdentifier: UUID().uuidString
        )

        guard entry.quantity.doubleValue(for: .gram()) > 0 else {
            return
        }

        carbEntryUnderConsideration = entry
        recommendBolus(for: entry)
    }

    private func recommendBolus(for entry: NewCarbEntry) {
        let potentialEntry = PotentialCarbEntryUserInfo(carbEntry: entry)
        do {
            isComputingRecommendedBolus = true
            try WCSession.default.sendPotentialCarbEntryMessage(potentialEntry,
                replyHandler: { [weak self] context in
                    DispatchQueue.main.async {
                        let loopManager = ExtensionDelegate.shared().loopManager
                        loopManager.updateContext(context)

                        guard let self = self else {
                            return
                        }

                        // Only update if this recommendation corresponds to the current carb entry under consideration.
                        guard context.potentialCarbEntry == self.carbEntryUnderConsideration else {
                            return
                        }

                        defer {
                            self.isComputingRecommendedBolus = false
                        }

                        // Don't publish a new value if the recommendation has not changed.
                        guard self.recommendedBolusAmount != context.recommendedBolusDoseConsideringPotentialCarbEntry else {
                            return
                        }

                        self.recommendedBolusAmount = context.recommendedBolusDoseConsideringPotentialCarbEntry
                    }
                },
                errorHandler: { error in
                    DispatchQueue.main.async { [weak self] in
                        self?.isComputingRecommendedBolus = false
                        WKInterfaceDevice.current().play(.failure)
                        ExtensionDelegate.shared().present(error)
                    }
                }
            )
        } catch {
            isComputingRecommendedBolus = false
            presentAlert(
                withTitle: NSLocalizedString("Send Failed", comment: "The title of the alert controller displayed after a potential carb entry send attempt fails"),
                message: NSLocalizedString("Make sure your iPhone is nearby and try again", comment: "The recovery message displayed after a potential carb entry send attempt fails")
            )
        }
    }

    private func absorptionTime(for carbAbsorptionTime: CarbAbsorptionTime) -> TimeInterval {
        let defaultTimes = LoopSettings.defaultCarbAbsorptionTimes

        switch carbAbsorptionTime {
        case .fast:
            return defaultTimes.fast
        case .medium:
            return defaultTimes.medium
        case .slow:
            return defaultTimes.slow
        }
    }

    func addCarbsWithoutBolusing() {
        guard let carbEntry = carbEntryUnderConsideration else {
            assertionFailure("Attempting to add carbs without a carb entry")
            return
        }

        sendSetBolusUserInfo(carbEntry: carbEntry, bolus: 0)
    }

    func addCarbsAndDeliverBolus(_ bolusAmount: Double) {
        sendSetBolusUserInfo(carbEntry: carbEntryUnderConsideration, bolus: bolusAmount)
    }

    private func sendSetBolusUserInfo(carbEntry: NewCarbEntry?, bolus: Double) {
        let bolus = SetBolusUserInfo(value: bolus, startDate: Date(), carbEntry: carbEntry)
        do {
            try WCSession.default.sendBolusMessage(bolus) { (error) in
                DispatchQueue.main.async {
                    if let error = error {
                        ExtensionDelegate.shared().present(error)
                    } else {
                        let loopManager = ExtensionDelegate.shared().loopManager
                        if let carbEntry = bolus.carbEntry {
                            loopManager.addConfirmedCarbEntry(carbEntry)

                            if bolus.value == 0 {
                                // Notify for a successful carb entry (sans bolus)
                                WKInterfaceDevice.current().play(.success)
                            }
                        }
                        loopManager.addConfirmedBolus(bolus)
                    }
                }
            }
        } catch {
            presentAlert(
                withTitle: NSLocalizedString("Bolus Failed", comment: "The title of the alert controller displayed after a bolus attempt fails"),
                message: NSLocalizedString("Make sure your iPhone is nearby and try again", comment: "The recovery message displayed after a bolus attempt fails")
            )
        }
    }

    func dismiss() {
        _dismiss()
    }

    private func presentAlert(withTitle title: String, message: String) {
        _presentAlert(title, message)
    }
}
