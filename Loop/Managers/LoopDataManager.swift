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

    var pumpInsulinType: InsulinType?

    private var doseStore: DoseStore
    private var settingsStore: SettingsStore
    private var carbStore: CarbStore
    private var glucoseStore: GlucoseStore

    init(doseStore: DoseStore, settingsStore: SettingsStore, carbStore: CarbStore, glucoseStore: GlucoseStore) {
        self.doseStore = doseStore
        self.settingsStore = settingsStore
        self.carbStore = carbStore
        self.glucoseStore = glucoseStore
    }

    func loop() async {
        let baseTime = Date()

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

            // TODO: overlay overrides

            let input = LoopAlgorithmInput(
                predictionStart: baseTime,
                glucoseHistory: glucose,
                doses: doses,
                carbEntries: carbEntries,
                basal: basal,
                sensitivity: sensitivity,
                carbRatio: carbRatio,
                target: target,
                suspendThreshold: dosingLimits.suspendThreshold,
                maxBolus: maxBolus,
                maxBasalRate: maxBasalRate,
                useIntegralRetrospectiveCorrection: UserDefaults.standard.integralRetrospectiveCorrectionEnabled,
                recommendationInsulinType: pumpInsulinType ?? .novolog,
                recommendationType: dosingStrategy.recommendationType
            )
        } catch {
            print("error looping: \(error)")
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
