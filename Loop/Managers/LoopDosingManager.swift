//
//  LoopDosingManager.swift
//  Loop
//
//  Created by Pete Schwamb on 10/24/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit

enum AlgorithmDisplayState {
    case uninitialized
    case error(LoopError)
    case ready(input: LoopAlgorithmInput, output: LoopAlgorithmOutput)
}

protocol DosingDelegate {
    var isSuspended: Bool { get }
    var manualTempBasalRunning: Bool { get }
    var pumpInsulinType: InsulinType? { get }

    func enact(_ recommendation: AutomaticDoseRecommendation) async throws
    func roundBasalRate(unitsPerHour: Double) -> Double
    func roundBolusVolume(units: Double) -> Double
}

actor LoopDosingManager {

    // Represents the current state of the loop algorithm for display
    var displayState: AlgorithmDisplayState = .uninitialized

    var automaticDosingEnabled: Bool = true

    private let doseStore: DoseStore
    private let settingsStore: SettingsStore
    private let carbStore: CarbStore
    private let glucoseStore: GlucoseStore
    private let overrideHistory: TemporaryScheduleOverrideHistory
    private let dosingDecisionStore: DosingDecisionStore
    private let dosingDelegate: DosingDelegate

    private let logger = DiagnosticLog(category: "LoopDosingManager")


    init(
        doseStore: DoseStore,
        settingsStore: SettingsStore,
        carbStore: CarbStore,
        glucoseStore: GlucoseStore,
        overrideHistory: TemporaryScheduleOverrideHistory,
        dosingDecisionStore: DosingDecisionStore,
        dosingDelegate: DosingDelegate
    ) {
        self.doseStore = doseStore
        self.settingsStore = settingsStore
        self.carbStore = carbStore
        self.glucoseStore = glucoseStore
        self.overrideHistory = overrideHistory
        self.dosingDecisionStore = dosingDecisionStore
        self.dosingDelegate = dosingDelegate
    }


    func fetchData(for baseTime: Date = Date()) async throws -> LoopAlgorithmInput {
        // Need to fetch doses back as far as t - (DIA + DCA) for Dynamic carbs
        let dosesInputHistory = CarbMath.maximumAbsorptionTimeInterval + InsulinMath.defaultInsulinActivityDuration

        var dosesStart = baseTime.addingTimeInterval(-dosesInputHistory)
        let doses = try await doseStore.getDoses(
            start: dosesStart,
            end: baseTime
        )

        dosesStart = doses.map { $0.startDate }.min() ?? dosesStart

        let basal = try await settingsStore.getBasalHistory(startDate: dosesStart, endDate: baseTime)

        let forecastEndTime = baseTime.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration).dateCeiledToTimeInterval(.minutes(GlucoseMath.defaultDelta))

        let carbsStart = baseTime.addingTimeInterval(-CarbMath.maximumAbsorptionTimeInterval)

        // Include future carbs in query, but filter out ones entered after basetime.
        let carbEntries = try await carbStore.getCarbEntries(
            start: carbsStart,
            end: forecastEndTime
        ).filter {
            $0.userCreatedDate ?? $0.startDate < baseTime
        }

        let carbRatio = try await settingsStore.getCarbRatioHistory(
            startDate: carbsStart,
            endDate: forecastEndTime
        )

        let glucose = try await glucoseStore.getGlucoseSamples(start: carbsStart, end: baseTime)

        let sensitivityStart = min(carbsStart, dosesStart)

        let sensitivity = try await settingsStore.getInsulinSensitivityHistory(startDate: sensitivityStart, endDate: forecastEndTime)

        let target = try await settingsStore.getTargetRangeHistory(startDate: baseTime, endDate: forecastEndTime)

        let dosingLimits = try await settingsStore.getDosingLimits(at: baseTime)

        guard let maxBolus = dosingLimits.maxBolus else {
            throw LoopError.configurationError(.maximumBolus)
        }
        
        guard let maxBasalRate = dosingLimits.maxBasalRate else {
            throw LoopError.configurationError(.maximumBasalRatePerHour)
        }

        let overrides = overrideHistory.getOverrideHistory(startDate: sensitivityStart, endDate: forecastEndTime)

        let sensitivityWithOverrides = overrides.apply(over: sensitivity) { (quantity, override) in
            let value = quantity.doubleValue(for: .milligramsPerDeciliter)
            return HKQuantity(
                unit: .milligramsPerDeciliter,
                doubleValue: value / override.settings.effectiveInsulinNeedsScaleFactor
            )
        }

        let basalWithOverrides = overrides.apply(over: basal) { (value, override) in
            value * override.settings.effectiveInsulinNeedsScaleFactor
        }

        let carbRatioWithOverrides = overrides.apply(over: carbRatio) { (value, override) in
            value * override.settings.effectiveInsulinNeedsScaleFactor
        }

        let targetWithOverrides = overrides.apply(over: target) { (range, override) in
            override.settings.targetRange ?? range
        }

        let carbModel: CarbAbsorptionModel = FeatureFlags.nonlinearCarbModelEnabled ? .piecewiseLinear : .linear

        return LoopAlgorithmInput(
            predictionStart: baseTime,
            glucoseHistory: glucose,
            doses: doses,
            carbEntries: carbEntries,
            basal: basalWithOverrides,
            sensitivity: sensitivityWithOverrides,
            carbRatio: carbRatioWithOverrides,
            target: targetWithOverrides,
            suspendThreshold: dosingLimits.suspendThreshold,
            maxBolus: maxBolus,
            maxBasalRate: maxBasalRate,
            useIntegralRetrospectiveCorrection: UserDefaults.standard.integralRetrospectiveCorrectionEnabled,
            carbAbsorptionModel: carbModel,
            recommendationInsulinType: dosingDelegate.pumpInsulinType ?? .novolog,
            recommendationType: .manualBolus
        )
    }

    func updateDisplayState() async {
        do {
            var input = try await fetchData()
            input.recommendationType = .manualBolus
            let output = try LoopAlgorithm.run(input: input)
            displayState = .ready(input: input, output: output)
        } catch {
            let loopError = error as? LoopError ?? .unknownError(error)
            logger.error("Error looping: %{public}@", String(describing: loopError))
            displayState = .error(loopError)
        }
    }

    func loop() async {
        guard automaticDosingEnabled else {
            return
        }

        do {
            let loopBaseTime = Date()

            var input = try await fetchData(for: loopBaseTime)

            let dosingStrategy = settingsStore.latestSettings?.automaticDosingStrategy ?? .tempBasalOnly
            input.recommendationType = dosingStrategy.recommendationType

            let output = try LoopAlgorithm.run(input: input)

            displayState = .ready(input: input, output: output)

            var recommendation = output.doseRecommendation.automatic!

            // Round bolus recommendation based on pump bolus precision
            if let bolus = recommendation.bolusUnits, bolus > 0 {
                recommendation.bolusUnits = dosingDelegate.roundBolusVolume(units: bolus)
            }

            if let basal = recommendation.basalAdjustment {
                let basalRate = dosingDelegate.roundBasalRate(unitsPerHour: basal.unitsPerHour)

                let lastTempBasal = input.doses.first { $0.type == .tempBasal && $0.startDate < input.predictionStart && $0.endDate > input.predictionStart }
                let scheduledBasalRate = input.basal.closestPrior(to: loopBaseTime)!.value
                let activeOverride = overrideHistory.activeOverride(at: loopBaseTime)

                let basalAdjustment = recommendation.basalAdjustment?.ifNecessary(
                    at: loopBaseTime,
                    neutralBasalRate: scheduledBasalRate,
                    lastTempBasal: lastTempBasal,
                    continuationInterval: .minutes(11),
                    neutralBasalRateMatchesPump: activeOverride == nil
                )
            }

            var dosingDecision = StoredDosingDecision(
                date: loopBaseTime,
                reason: "loop"
            )
            dosingDecision.updateFrom(input: input, output: output)

            if dosingDelegate.isSuspended {
                throw LoopError.pumpSuspended
            }

            try await dosingDelegate.enact(recommendation)

            dosingDecisionStore.storeDosingDecision(dosingDecision) {}
        } catch {
            let loopError = error as? LoopError ?? .unknownError(error)
            var dosingDecision = StoredDosingDecision(date: Date(), reason: "loop")
            dosingDecision.appendError(loopError)
            dosingDecisionStore.storeDosingDecision(dosingDecision) {}
        }
    }
}

extension AutomaticDosingStrategy {
    var recommendationType: DoseRecommendationType {
        switch self {
        case .tempBasalOnly:
            return .tempBasal
        case .automaticBolus:
            return .automaticBolus
        }
    }
}

extension StoredDosingDecision {
    mutating func updateFrom(input: LoopAlgorithmInput, output: LoopAlgorithmOutput) {
        self.historicalGlucose = input.glucoseHistory.map { HistoricalGlucoseValue(startDate: $0.startDate, quantity: $0.quantity) }
        self.insulinOnBoard = InsulinValue(startDate: input.predictionStart, value: output.activeInsulin)
        self.carbsOnBoard = CarbValue(startDate: input.predictionStart, value: output.activeCarbs)
        self.predictedGlucose = output.predictedGlucose
        self.automaticDoseRecommendation = output.doseRecommendation.automatic
    }
}
