//
//  ForecastGenerator.swift
//  Loop
//
//  Created by Rick Pasetto on 9/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

enum ForecastGenerator {}

extension ForecastGenerator {
    /// When combining retrospective glucose discrepancies, extend the window slightly as a buffer.
    private static var retrospectiveCorrectionGroupingIntervalMultiplier: Double { 1.01 }
            
    /// - Throws:
    ///     - LoopError.missingDataError
    ///     - LoopError.configurationError
    ///     - LoopError.glucoseTooOld
    ///     - LoopError.pumpDataTooOld
    public static func predictGlucose(
        startingFrom now: Date,
        using inputs: PredictionInputEffect,
        model: InsulinModel,
        startingAt glucose: GlucoseValue,
        pumpStatusDate: Date,
        insulinCounteractionEffects: [GlucoseEffectVelocity],
        retrospectiveCorrection: RetrospectiveCorrection,
        retrospectiveCorrectionGroupingInterval: TimeInterval = TimeInterval(minutes: 30),
        retrospectiveGlucoseEffect: [GlucoseEffect],
        effectInterval: TimeInterval,
        recentCarbEntries: [StoredCarbEntry]?,
        inputDataRecencyInterval: TimeInterval = TimeInterval(minutes: 15),
        insulinEffect: [GlucoseEffect]? = nil,
        carbEffect: [GlucoseEffect]? = nil,
        potentialBolus: DoseEntry? = nil,
        potentialCarbEntry: NewCarbEntry? = nil,
        replacingCarbEntry replacedCarbEntry: StoredCarbEntry? = nil,
        includingPendingInsulin: Bool = false,
        insulinEffectIncludingPendingInsulin: [GlucoseEffect]? = nil,
        insulinSensitivitySchedule: InsulinSensitivitySchedule,
        insulinSensitivityScheduleApplyingOverrideHistory: InsulinSensitivitySchedule? = nil,
        carbRatioSchedule: CarbRatioSchedule,
        basalRateSchedule: BasalRateSchedule?,
        glucoseCorrectionRangeSchedule: GlucoseRangeSchedule?,
        glucoseMomentumEffect: [GlucoseEffect]?,
        absorptionTimeOverrun: Double,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval,
        delta: Double,
        initialAbsorptionTimeOverrun: Double,
        absorptionModel: CarbAbsorptionComputable,
        adaptiveAbsorptionRateEnabled: Bool,
        adaptiveRateStandbyIntervalFraction: Double
    ) throws -> [PredictedGlucoseValue] {
        
        let lastGlucoseDate = glucose.startDate
        
        guard now.timeIntervalSince(lastGlucoseDate) <= inputDataRecencyInterval else {
            throw LoopError.glucoseTooOld(date: glucose.startDate)
        }
        
        guard now.timeIntervalSince(pumpStatusDate) <= inputDataRecencyInterval else {
            throw LoopError.pumpDataTooOld(date: pumpStatusDate)
        }
        
        var momentum: [GlucoseEffect] = []
        var effects: [[GlucoseEffect]] = []
        var retrospectiveGlucoseEffect = retrospectiveGlucoseEffect
        if inputs.contains(.carbs) {
            try ForecastGenerator.generateEffectsForCarbs(potentialCarbEntry: potentialCarbEntry,
                                                          lastGlucoseDate: lastGlucoseDate,
                                                          recentCarbEntries: recentCarbEntries,
                                                          replacedCarbEntry: replacedCarbEntry,
                                                          carbEffect: carbEffect,
                                                          insulinCounteractionEffects: insulinCounteractionEffects,
                                                          retrospectiveCorrection: retrospectiveCorrection,
                                                          glucose: glucose,
                                                          effectInterval: effectInterval,
                                                          inputDataRecencyInterval: inputDataRecencyInterval,
                                                          retrospectiveCorrectionGroupingInterval: retrospectiveCorrectionGroupingInterval,
                                                          carbRatioSchedule: carbRatioSchedule,
                                                          insulinSensitivitySchedule: insulinSensitivitySchedule,
                                                          basalRateSchedule: basalRateSchedule,
                                                          glucoseCorrectionRangeSchedule: glucoseCorrectionRangeSchedule,
                                                          absorptionTimeOverrun: absorptionTimeOverrun,
                                                          defaultAbsorptionTime: defaultAbsorptionTime,
                                                          delay: delay,
                                                          delta: delta,
                                                          initialAbsorptionTimeOverrun: initialAbsorptionTimeOverrun,
                                                          absorptionModel: absorptionModel,
                                                          adaptiveAbsorptionRateEnabled: adaptiveAbsorptionRateEnabled,
                                                          adaptiveRateStandbyIntervalFraction: adaptiveRateStandbyIntervalFraction,
                                                          effects: &effects,
                                                          retrospectiveGlucoseEffect: &retrospectiveGlucoseEffect
            )
        }
        
        if inputs.contains(.insulin) {
            try ForecastGenerator.generateEffectsForInsulin(insulinEffect: insulinEffect,
                                                            includingPendingInsulin: includingPendingInsulin,
                                                            insulinEffectIncludingPendingInsulin: insulinEffectIncludingPendingInsulin,
                                                            potentialBolus: potentialBolus,
                                                            insulinSensitivityScheduleApplyingOverrideHistory: insulinSensitivityScheduleApplyingOverrideHistory,
                                                            now: now,
                                                            insulinCounteractionEffects: insulinCounteractionEffects,
                                                            model: model,
                                                            effects: &effects
            )
        }
        
        if inputs.contains(.momentum), let momentumEffect = glucoseMomentumEffect {
            momentum = momentumEffect
        }
        
        if inputs.contains(.retrospection) {
            effects.append(retrospectiveGlucoseEffect)
        }
        
        var prediction = LoopMath.predictGlucose(startingAt: glucose, momentum: momentum, effects: effects)
        
        // Dosing requires prediction entries at least as long as the insulin model duration.
        // If our prediction is shorter than that, then extend it here.
        let finalDate = glucose.startDate.addingTimeInterval(model.effectDuration)
        if let last = prediction.last, last.startDate < finalDate {
            prediction.append(PredictedGlucoseValue(startDate: finalDate, quantity: last.quantity))
        }
        
        return prediction
    }
    
    private static func generateEffectsForCarbs(potentialCarbEntry: NewCarbEntry?,
                                                lastGlucoseDate: Date,
                                                recentCarbEntries: [StoredCarbEntry]?,
                                                replacedCarbEntry: StoredCarbEntry?,
                                                carbEffect: [GlucoseEffect]?,
                                                insulinCounteractionEffects: [GlucoseEffectVelocity],
                                                retrospectiveCorrection: RetrospectiveCorrection,
                                                glucose: GlucoseValue,
                                                effectInterval: TimeInterval,
                                                inputDataRecencyInterval: TimeInterval,
                                                retrospectiveCorrectionGroupingInterval: TimeInterval,
                                                carbRatioSchedule: CarbRatioSchedule,
                                                insulinSensitivitySchedule: InsulinSensitivitySchedule,
                                                basalRateSchedule: BasalRateSchedule?,
                                                glucoseCorrectionRangeSchedule: GlucoseRangeSchedule?,
                                                absorptionTimeOverrun: Double,
                                                defaultAbsorptionTime: TimeInterval,
                                                delay: TimeInterval,
                                                delta: Double,
                                                initialAbsorptionTimeOverrun: Double,
                                                absorptionModel: CarbAbsorptionComputable,
                                                adaptiveAbsorptionRateEnabled: Bool,
                                                adaptiveRateStandbyIntervalFraction: Double,
                                                effects: inout [[GlucoseEffect]],
                                                retrospectiveGlucoseEffect: inout [GlucoseEffect]
    ) throws {
        
        if let potentialCarbEntry = potentialCarbEntry {
            let retrospectiveStart = lastGlucoseDate.addingTimeInterval(-retrospectiveCorrection.retrospectionInterval)
            
            if potentialCarbEntry.startDate > lastGlucoseDate || recentCarbEntries?.isEmpty != false, replacedCarbEntry == nil {
                // The potential carb effect is independent and can be summed with the existing effect
                if let carbEffect = carbEffect {
                    effects.append(carbEffect)
                }
                
//                let potentialCarbEffect = try generateGlucoseEffects(
//                    [potentialCarbEntry],
//                    retrospectiveStart,
//                    nil,
//                    insulinCounteractionEffects
//                )
                let potentialCarbEffect = try generateGlucoseEffects(carbRatioSchedule: carbRatioSchedule, insulinSensitivitySchedule: insulinSensitivitySchedule, of: [potentialCarbEntry], startingAt: retrospectiveStart, endingAt: nil, effectVelocities: insulinCounteractionEffects, absorptionTimeOverrun: absorptionTimeOverrun, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay, delta: delta, initialAbsorptionTimeOverrun: initialAbsorptionTimeOverrun, absorptionModel: absorptionModel, adaptiveAbsorptionRateEnabled: adaptiveAbsorptionRateEnabled, adaptiveRateStandbyIntervalFraction: adaptiveRateStandbyIntervalFraction)
                
                effects.append(potentialCarbEffect)
            } else {
                var recentEntries = recentCarbEntries ?? []
                if let replacedCarbEntry = replacedCarbEntry, let index = recentEntries.firstIndex(of: replacedCarbEntry) {
                    recentEntries.remove(at: index)
                }
                
                // If the entry is in the past or an entry is replaced, DCA and RC effects must be recomputed
                var entries = recentEntries.map { NewCarbEntry(quantity: $0.quantity, startDate: $0.startDate, foodType: nil, absorptionTime: $0.absorptionTime) }
                entries.append(potentialCarbEntry)
                entries.sort(by: { $0.startDate > $1.startDate })
                
//                let potentialCarbEffect = try generateGlucoseEffects(
//                    entries,
//                    retrospectiveStart,
//                    nil,
//                    insulinCounteractionEffects
//                )
                let potentialCarbEffect = try generateGlucoseEffects(carbRatioSchedule: carbRatioSchedule, insulinSensitivitySchedule: insulinSensitivitySchedule, of: entries, startingAt: retrospectiveStart, endingAt: nil, effectVelocities: insulinCounteractionEffects, absorptionTimeOverrun: absorptionTimeOverrun, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay, delta: delta, initialAbsorptionTimeOverrun: initialAbsorptionTimeOverrun, absorptionModel: absorptionModel, adaptiveAbsorptionRateEnabled: adaptiveAbsorptionRateEnabled, adaptiveRateStandbyIntervalFraction: adaptiveRateStandbyIntervalFraction)

                effects.append(potentialCarbEffect)
                
                retrospectiveGlucoseEffect = ForecastGenerator.computeRetrospectiveGlucoseEffect(
                    retrospectiveCorrection: retrospectiveCorrection,
                    startingAt: glucose,
                    carbEffects: potentialCarbEffect,
                    effectInterval: effectInterval,
                    inputDataRecencyInterval: inputDataRecencyInterval,
                    insulinCounteractionEffects: insulinCounteractionEffects,
                    retrospectiveCorrectionGroupingInterval: retrospectiveCorrectionGroupingInterval,
                    insulinSensitivitySchedule: insulinSensitivitySchedule,
                    basalRateSchedule: basalRateSchedule,
                    glucoseCorrectionRangeSchedule: glucoseCorrectionRangeSchedule)
            }
        } else if let carbEffect = carbEffect {
            effects.append(carbEffect)
        }
    }

    private static func generateEffectsForInsulin(insulinEffect: [GlucoseEffect]?,
                                                  includingPendingInsulin: Bool,
                                                  insulinEffectIncludingPendingInsulin: [GlucoseEffect]?,
                                                  potentialBolus: DoseEntry?,
                                                  insulinSensitivityScheduleApplyingOverrideHistory: InsulinSensitivitySchedule?,
                                                  now: Date,
                                                  insulinCounteractionEffects: [GlucoseEffectVelocity],
                                                  model: InsulinModel,
                                                  effects: inout [[GlucoseEffect]]
    ) throws {
        
        let computationInsulinEffect: [GlucoseEffect]?
        if insulinEffect != nil {
            computationInsulinEffect = insulinEffect
        } else {
            computationInsulinEffect = includingPendingInsulin ? insulinEffectIncludingPendingInsulin : insulinEffect
        }
        
        if let insulinEffect = computationInsulinEffect {
            effects.append(insulinEffect)
        }
        
        if let potentialBolus = potentialBolus {
            guard let sensitivity = insulinSensitivityScheduleApplyingOverrideHistory else {
                throw LoopError.configurationError(.generalSettings)
            }
            
            let earliestEffectDate = Date(timeInterval: .hours(-24), since: now)
            let nextEffectDate = insulinCounteractionEffects.last?.endDate ?? earliestEffectDate
            let bolusEffect = [potentialBolus]
                .glucoseEffects(insulinModel: model, insulinSensitivity: sensitivity)
                .filterDateRange(nextEffectDate, nil)
            effects.append(bolusEffect)
        }
    }

    private static func computeRetrospectiveGlucoseEffect(
        retrospectiveCorrection: RetrospectiveCorrection,
        startingAt glucose: GlucoseValue,
        carbEffects: [GlucoseEffect],
        effectInterval: TimeInterval,
        inputDataRecencyInterval: TimeInterval,
        insulinCounteractionEffects: [GlucoseEffectVelocity],
        retrospectiveCorrectionGroupingInterval: TimeInterval,
        insulinSensitivitySchedule: InsulinSensitivitySchedule?,
        basalRateSchedule: BasalRateSchedule?,
        glucoseCorrectionRangeSchedule: GlucoseRangeSchedule?
        ) -> [GlucoseEffect] {
        let retrospectiveGlucoseDiscrepancies = insulinCounteractionEffects.subtracting(carbEffects, withUniformInterval: effectInterval)
        let retrospectiveGlucoseDiscrepanciesSummed = retrospectiveGlucoseDiscrepancies.combinedSums(of: retrospectiveCorrectionGroupingInterval * retrospectiveCorrectionGroupingIntervalMultiplier)
        return retrospectiveCorrection.computeEffect(
            startingAt: glucose,
            retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
            recencyInterval: inputDataRecencyInterval,
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            basalRateSchedule: basalRateSchedule,
            glucoseCorrectionRangeSchedule: glucoseCorrectionRangeSchedule,
            retrospectiveCorrectionGroupingInterval: retrospectiveCorrectionGroupingInterval
        )
    }

    /// Computes a timeline of effects on blood glucose from carbohydrates
    /// - Parameters:
    ///   - start: The earliest date of effects to retrieve
    ///   - end: The latest date of effects to retrieve, if provided
    ///   - effectVelocities: A timeline of glucose effect velocities, ordered by start date
    private static func generateGlucoseEffects<Sample: CarbEntry>(
        carbRatioSchedule: CarbRatioSchedule,
        insulinSensitivitySchedule: InsulinSensitivitySchedule,
        of samples: [Sample],
        startingAt start: Date,
        endingAt end: Date? = nil,
        effectVelocities: [GlucoseEffectVelocity]? = nil,
        absorptionTimeOverrun: Double,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval,
        delta: Double,
        initialAbsorptionTimeOverrun: Double,
        absorptionModel: CarbAbsorptionComputable,
        adaptiveAbsorptionRateEnabled: Bool,
        adaptiveRateStandbyIntervalFraction: Double
    ) throws -> [GlucoseEffect] {

        if let effectVelocities = effectVelocities {
            return samples.map(
                to: effectVelocities,
                carbRatio: carbRatioSchedule,
                insulinSensitivity: insulinSensitivitySchedule,
                absorptionTimeOverrun: absorptionTimeOverrun,
                defaultAbsorptionTime: defaultAbsorptionTime,
                delay: delay,
                initialAbsorptionTimeOverrun: initialAbsorptionTimeOverrun,
                absorptionModel: absorptionModel,
                adaptiveAbsorptionRateEnabled: adaptiveAbsorptionRateEnabled,
                adaptiveRateStandbyIntervalFraction: adaptiveRateStandbyIntervalFraction
            ).dynamicGlucoseEffects(
                from: start,
                to: end,
                carbRatios: carbRatioSchedule,
                insulinSensitivities: insulinSensitivitySchedule,
                defaultAbsorptionTime: defaultAbsorptionTime,
                absorptionModel: absorptionModel,
                delay: delay,
                delta: delta
            )
        } else {
            return samples.glucoseEffects(
                from: start,
                to: end,
                carbRatios: carbRatioSchedule,
                insulinSensitivities: insulinSensitivitySchedule,
                defaultAbsorptionTime: defaultAbsorptionTime,
                absorptionModel: absorptionModel,
                delay: delay,
                delta: delta
            )
        }
    }

}
