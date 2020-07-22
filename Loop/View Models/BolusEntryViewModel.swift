//
//  BolusEntryViewModel.swift
//  Loop
//
//  Created by Michael Pangburn on 7/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import HealthKit
import LocalAuthentication
import Intents
import os.log
import LoopKit
import LoopUI


final class BolusEntryViewModel: ObservableObject {
    enum Alert: Int {
        case recommendationChanged
        case maxBolusExceeded
    }

    @Published var glucoseValues: [GlucoseValue] = []
    @Published var predictedGlucoseValues: [GlucoseValue] = []
    @Published var glucoseUnit: HKUnit = .milligramsPerDeciliter

    @Published var activeCarbs: HKQuantity?
    @Published var activeInsulin: HKQuantity?

    @Published var targetGlucoseSchedule: GlucoseRangeSchedule?
    @Published var preMealOverride: TemporaryScheduleOverride?
    @Published var scheduleOverride: TemporaryScheduleOverride?
    var maximumBolus = HKQuantity(unit: .internationalUnit(), doubleValue: 25)

    let originalCarbEntry: StoredCarbEntry?
    let potentialCarbEntry: NewCarbEntry?
    let selectedCarbAbsorptionTimeEmoji: String?

    @Published var recommendedBolus: HKQuantity?
    @Published var enteredBolus = HKQuantity(unit: .internationalUnit(), doubleValue: 0)

    @Published var chartDateInterval = DateInterval(start: Date(), duration: .hours(6))
    let glucoseChartHeight: CGFloat?

    @Published var activeAlert: Alert?

    private let dataManager: DeviceDataManager
    private let log = OSLog(category: "BolusEntryViewModel")
    private var cancellables: Set<AnyCancellable> = []

    let chartManager: ChartsManager = {
        let predictedGlucoseChart = PredictedGlucoseChart()
        predictedGlucoseChart.glucoseDisplayRange = BolusEntryViewModel.defaultGlucoseDisplayRange
        return ChartsManager(colors: .default, settings: .default, charts: [predictedGlucoseChart], traitCollection: .current)
    }()

    static let defaultGlucoseDisplayRange = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 60)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200)

    init(
        dataManager: DeviceDataManager,
        glucoseChartHeight: CGFloat?,
        originalCarbEntry: StoredCarbEntry? = nil,
        potentialCarbEntry: NewCarbEntry? = nil,
        selectedCarbAbsorptionTimeEmoji: String? = nil
    ) {
        self.dataManager = dataManager
        self.glucoseChartHeight = glucoseChartHeight
        self.originalCarbEntry = originalCarbEntry
        self.potentialCarbEntry = potentialCarbEntry
        self.selectedCarbAbsorptionTimeEmoji = selectedCarbAbsorptionTimeEmoji

        NotificationCenter.default
            .publisher(for: .LoopDataUpdated, object: dataManager.loopManager)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)

        $enteredBolus
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.updatePredictedGlucoseValues() }
            .store(in: &cancellables)

        update()
    }

    var isBolusRecommended: Bool {
        guard let recommendedBolus = recommendedBolus else {
            return false
        }

        return recommendedBolus.doubleValue(for: .internationalUnit()) > 0
    }

    func saveCarbsAndDeliverBolus() {
        guard enteredBolus < maximumBolus else {
            activeAlert = .maxBolusExceeded
            return
        }

        guard let carbEntry = potentialCarbEntry else {
            authenticateAndDeliverBolus()
            return
        }

        if originalCarbEntry == nil {
            let interaction = INInteraction(intent: NewCarbEntryIntent(), response: nil)
            interaction.donate { [weak self] (error) in
                if let error = error {
                    self?.log.error("Failed to donate intent: %{public}@", String(describing: error))
                }
            }
        }

        dataManager.loopManager.addCarbEntry(carbEntry) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.authenticateAndDeliverBolus()
                case .failure(let error):
                    self.log.error("Failed to add carb entry: %{public}@", String(describing: error))
                }
            }
        }
    }

    private func authenticateAndDeliverBolus() {
        let bolusVolume = enteredBolus.doubleValue(for: .internationalUnit())
        guard bolusVolume > 0 else { return }

        let context = LAContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(format: NSLocalizedString("Authenticate to Bolus %@ Units", comment: "The message displayed during a device authentication prompt for bolus specification"), enteredBolusAmountString),
                reply: { success, error in
                    if success {
                        DispatchQueue.main.async {
                            self.dataManager.enactBolus(units: bolusVolume)
                        }
                    }
                }
            )
        } else {
            dataManager.enactBolus(units: bolusVolume)
        }
    }

    private lazy var bolusVolumeFormatter = QuantityFormatter(for: .internationalUnit())

    var enteredBolusAmountString: String {
        let bolusVolume = enteredBolus.doubleValue(for: .internationalUnit())
        return bolusVolumeFormatter.numberFormatter.string(from: bolusVolume) ?? String(bolusVolume)
    }

    var maximumBolusAmountString: String {
        let maxBolusVolume = maximumBolus.doubleValue(for: .internationalUnit())
        return bolusVolumeFormatter.numberFormatter.string(from: maxBolusVolume) ?? String(maxBolusVolume)
    }

    var carbEntryAndAbsorptionTimeString: String? {
        guard
            let potentialCarbEntry = potentialCarbEntry,
            let carbAmountString = QuantityFormatter(for: .gram()).string(from: potentialCarbEntry.quantity, for: .gram())
        else {
            return nil
        }

        if let emoji = potentialCarbEntry.foodType ?? selectedCarbAbsorptionTimeEmoji {
            return String(format: NSLocalizedString("%1$@ %2$@", comment: "Format string combining carb entry quantity and absorption time emoji"), carbAmountString, emoji)
        } else {
            return carbAmountString
        }
    }

    private func update() {
        chartDateInterval = updatedChartDateInterval()

        updateGlucoseValues()
        updatePredictedGlucoseValues()
        updateActiveInsulin()
        updateSettingsAndRecommendedBolus()
    }

    private func updateGlucoseValues() {
        dataManager.loopManager.glucoseStore.getCachedGlucoseSamples(start: chartDateInterval.start) { [weak self] values in
            DispatchQueue.main.async {
                self?.glucoseValues = values
            }
        }
    }

    private func updatePredictedGlucoseValues() {
        dataManager.loopManager.getLoopState { [weak self] manager, state in
            guard let self = self else { return }

            let enteredBolusDose = DoseEntry(type: .bolus, startDate: Date(), value: self.enteredBolus.doubleValue(for: .internationalUnit()), unit: .units)

            let predictedGlucoseValues: [GlucoseValue]
            do {
                predictedGlucoseValues = try state.predictGlucose(
                    using: .all,
                    potentialBolus: enteredBolusDose,
                    potentialCarbEntry: self.potentialCarbEntry,
                    replacingCarbEntry: self.originalCarbEntry,
                    includingPendingInsulin: true
                )
            } catch {
                predictedGlucoseValues = []
            }

            DispatchQueue.main.async {
                self.predictedGlucoseValues = predictedGlucoseValues
            }
        }
    }

    private func updateActiveInsulin() {
        dataManager.loopManager.doseStore.insulinOnBoard(at: Date()) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let iob):
                    self.activeInsulin = HKQuantity(unit: .internationalUnit(), doubleValue: iob.value)
                case .failure:
                    self.activeInsulin = nil
                }
            }
        }
    }

    private func updateSettingsAndRecommendedBolus() {
        dataManager.loopManager.getLoopState { [weak self] manager, state in
            guard let self = self else { return }

            let recommendedBolus = try? state.recommendBolus(
                consideringPotentialCarbEntry: self.potentialCarbEntry,
                replacingCarbEntry: self.originalCarbEntry
            ).map { recommendation in
                HKQuantity(unit: .internationalUnit(), doubleValue: recommendation.amount)
            }

            let activeCarbs = state.carbsOnBoard.map { $0.quantity }

            DispatchQueue.main.async {
                let priorRecommendedBolus = self.recommendedBolus
                self.recommendedBolus = recommendedBolus

                if priorRecommendedBolus != recommendedBolus, self.enteredBolus.doubleValue(for: .internationalUnit()) > 0 {
                    self.enteredBolus = HKQuantity(unit: .internationalUnit(), doubleValue: 0)
                    self.activeAlert = .recommendationChanged
                }

                self.glucoseUnit = manager.settings.glucoseUnit ?? manager.glucoseStore.preferredUnit ?? .milligramsPerDeciliter

                self.activeCarbs = activeCarbs

                self.targetGlucoseSchedule = manager.settings.glucoseTargetRangeSchedule
                self.preMealOverride = manager.settings.preMealOverride
                self.scheduleOverride = manager.settings.scheduleOverride

                if self.preMealOverride?.hasFinished() == true {
                    self.preMealOverride = nil
                }

                if self.scheduleOverride?.hasFinished() == true {
                    self.scheduleOverride = nil
                }

                if let maxBolusAmount = manager.settings.maximumBolus {
                    self.maximumBolus = HKQuantity(unit: .internationalUnit(), doubleValue: maxBolusAmount)
                }
            }
        }
    }

    private func updatedChartDateInterval() -> DateInterval {
        let settings = dataManager.loopManager.settings

        // How far back should we show data? Use the screen size as a guide.
        let screenWidth = UIScreen.main.bounds.width
        let viewMarginInset: CGFloat = 14
        let availableWidth = screenWidth - chartManager.fixedHorizontalMargin - 2 * viewMarginInset

        let totalHours = floor(Double(availableWidth / settings.minimumChartWidthPerHour))
        let futureHours = ceil((dataManager.loopManager.insulinModelSettings?.model.effectDuration ?? .hours(4)).hours)
        let historyHours = max(settings.statusChartMinimumHistoryDisplay.hours, totalHours - futureHours)

        let date = Date(timeIntervalSinceNow: -TimeInterval(hours: historyHours))
        let chartStartDate = Calendar.current.nextDate(
            after: date,
            matching: DateComponents(minute: 0),
            matchingPolicy: .strict,
            direction: .backward
        ) ?? date

        return DateInterval(start: chartStartDate, duration: .hours(totalHours))
    }
}

extension BolusEntryViewModel.Alert: Identifiable {
    var id: Self { self }
}
