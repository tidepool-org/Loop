//
//  LoopDataManager.swift
//  Loop
//
//  Created by Pete Schwamb on 10/24/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit

actor LoopDataManager {

    private let logger = DiagnosticLog(category: "LoopDataManager")

    var pumpInsulinType: InsulinType?

    private let doseStore: DoseStore
    private let settingsStore: SettingsStore
    private let carbStore: CarbStore
    private let glucoseStore: GlucoseStore
    private let overrideHistory: TemporaryScheduleOverrideHistory
    private let dosingDecisionStore: DosingDecisionStore

    init(
        doseStore: DoseStore,
        settingsStore: SettingsStore,
        carbStore: CarbStore,
        glucoseStore: GlucoseStore,
        overrideHistory: TemporaryScheduleOverrideHistory,
        dosingDecisionStore: DosingDecisionStore
    ) {
        self.doseStore = doseStore
        self.settingsStore = settingsStore
        self.carbStore = carbStore
        self.glucoseStore = glucoseStore
        self.overrideHistory = overrideHistory
        self.dosingDecisionStore = dosingDecisionStore
    }

    func loop() async {
        let baseTime = Date()

        var dosingDecision = StoredDosingDecision(date: baseTime, reason: "loop")

        do {
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

            guard let maxBolus = dosingLimits.maxBolus, let maxBasalRate = dosingLimits.maxBasalRate else {
                return
            }

            let dosingStrategy = settingsStore.latestSettings?.automaticDosingStrategy ?? .tempBasalOnly

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

            let input = LoopAlgorithmInput(
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
                recommendationInsulinType: pumpInsulinType ?? .novolog,
                recommendationType: dosingStrategy.recommendationType
            )
            let output = try LoopAlgorithm.run(input: input)
            dosingDecision.automaticDoseRecommendation = output.doseRecommendation.automatic
        } catch {
            let loopError = error as? LoopError ?? .unknownError(error)
            logger.error("Error looping: %{public}@", String(describing: loopError))
            dosingDecision.appendError(loopError)
        }
        dosingDecisionStore.storeDosingDecision(dosingDecision) {}
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

