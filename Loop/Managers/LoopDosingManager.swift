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
import Combine

enum AlgorithmDisplayState {
    case uninitialized
    case error(LoopError)
    case ready(input: LoopAlgorithmInput, output: LoopAlgorithmOutput)
}

protocol DosingDelegate {
    var isSuspended: Bool { get }
    var pumpInsulinType: InsulinType? { get }
    var basalDeliveryState: PumpManagerStatus.BasalDeliveryState? { get }

    func enact(_ recommendation: AutomaticDoseRecommendation) async throws
    func roundBasalRate(unitsPerHour: Double) -> Double
    func roundBolusVolume(units: Double) -> Double
}

actor LoopDosingManager {
    static let LoopUpdateContextKey = "com.loopkit.Loop.LoopDosingManager.LoopUpdateContext"

    enum LoopUpdateContext: Int {
        case insulin
        case carbs
        case glucose
        case preferences
        case loopFinished
    }

    // Represents the current state of the loop algorithm for display
    var displayState: AlgorithmDisplayState = .uninitialized

    private(set) var lastLoopCompleted: Date?

    private(set) var dosingDelegate: DosingDelegate?
    func setDosingDelegate(_ delegate: DosingDelegate?) {
        dosingDelegate = delegate
    }

    private let doseStore: DoseStore
    private let settingsStore: SettingsStore
    private let carbStore: CarbStore
    private let glucoseStore: GlucoseStore
    private let overrideHistory: TemporaryScheduleOverrideHistory
    private let dosingDecisionStore: DosingDecisionStore
    private let automaticDosingStatus: AutomaticDosingStatus
    private let analyticsServicesManager: AnalyticsServicesManager

    private let logger = DiagnosticLog(category: "LoopDosingManager")

    init(
        doseStore: DoseStore,
        settingsStore: SettingsStore,
        carbStore: CarbStore,
        glucoseStore: GlucoseStore,
        overrideHistory: TemporaryScheduleOverrideHistory,
        dosingDecisionStore: DosingDecisionStore,
        automaticDosingStatus: AutomaticDosingStatus,
        analyticsServicesManager: AnalyticsServicesManager
    ) {
        self.doseStore = doseStore
        self.settingsStore = settingsStore
        self.carbStore = carbStore
        self.glucoseStore = glucoseStore
        self.overrideHistory = overrideHistory
        self.dosingDecisionStore = dosingDecisionStore
        self.automaticDosingStatus = automaticDosingStatus
        self.analyticsServicesManager = analyticsServicesManager
    }


    private func fetchData(for baseTime: Date = Date()) async throws -> LoopAlgorithmInput {
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
            recommendationInsulinType: dosingDelegate?.pumpInsulinType ?? .novolog,
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

    /// Cancel the active temp basal if it was automatically issued
    func cancelActiveTempBasal(for reason: CancelActiveTempBasalReason) async {
        guard case .tempBasal(let dose) = dosingDelegate?.basalDeliveryState, (dose.automatic ?? true) else { return }

        logger.default("Cancelling active temp basal for reason: %{public}@", String(describing: reason))

        let recommendation = AutomaticDoseRecommendation(basalAdjustment: .cancel)

        var dosingDecision = StoredDosingDecision(reason: reason.rawValue)
        dosingDecision.settings = StoredDosingDecision.Settings(settingsStore.latestSettings)
        dosingDecision.automaticDoseRecommendation = recommendation

        do {
            try await dosingDelegate?.enact(recommendation)
        } catch {
            dosingDecision.appendError(error as? LoopError ?? .unknownError(error))
        }

        self.dosingDecisionStore.storeDosingDecision(dosingDecision) {}

        // Didn't actually run a loop, but this is similar to a loop() in that the automatic dosing
        // was updated.
        self.notify(forChange: .loopFinished)
    }

    private func notify(forChange context: LoopUpdateContext) {
        NotificationCenter.default.post(name: .LoopDataUpdated,
            object: self,
            userInfo: [
                type(of: self).LoopUpdateContextKey: context.rawValue
            ]
        )
    }


    func loop() async {
        guard self.automaticDosingStatus.automaticDosingEnabled else {
            self.logger.default("Not adjusting dosing during open loop.")
            return
        }

        let loopBaseTime = Date()

        do {
            guard let dosingDelegate else {
                preconditionFailure("Unable to dose without dosing delegate.")
            }

            logger.debug("Running Loop at %{public}@", String(describing: loopBaseTime))

            var input = try await fetchData(for: loopBaseTime)

            guard let glucose = input.glucoseHistory.last else {
                logger.error("Latest glucose missing")
                throw LoopError.missingDataError(.glucose)
            }

            let startDate = input.predictionStart

            if startDate.timeIntervalSince(glucose.startDate) > LoopAlgorithm.inputDataRecencyInterval {
                throw LoopError.glucoseTooOld(date: glucose.startDate)
            }

            if glucose.startDate.timeIntervalSince(startDate) > LoopAlgorithm.inputDataRecencyInterval {
                throw LoopError.invalidFutureGlucose(date: glucose.startDate)
            }

            let pumpStatusDate = doseStore.lastAddedPumpData

            if startDate.timeIntervalSince(pumpStatusDate) > LoopAlgorithm.inputDataRecencyInterval {
                throw LoopError.pumpDataTooOld(date: pumpStatusDate)
            }

            if input.target.isEmpty {
                throw LoopError.configurationError(.glucoseTargetRangeSchedule)
            }

            if input.basal.isEmpty {
                throw LoopError.configurationError(.basalRateSchedule)
            }

            if input.sensitivity.isEmpty {
                throw LoopError.configurationError(.insulinSensitivitySchedule)
            }

            if input.carbRatio.isEmpty {
                throw LoopError.configurationError(.carbRatioSchedule)
            }

            let dosingStrategy = settingsStore.latestSettings?.automaticDosingStrategy ?? .tempBasalOnly
            input.recommendationType = dosingStrategy.recommendationType

            let output = try LoopAlgorithm.run(input: input)

            // Update display state with each automatic loop
            displayState = .ready(input: input, output: output)

            var recommendation = output.doseRecommendation.automatic!

            // Round bolus recommendation based on pump bolus precision
            if let bolus = recommendation.bolusUnits, bolus > 0 {
                recommendation.bolusUnits = dosingDelegate.roundBolusVolume(units: bolus)
            }

            if var basal = recommendation.basalAdjustment {
                basal.unitsPerHour = dosingDelegate.roundBasalRate(unitsPerHour: basal.unitsPerHour)

                let lastTempBasal = input.doses.first { $0.type == .tempBasal && $0.startDate < input.predictionStart && $0.endDate > input.predictionStart }
                let scheduledBasalRate = input.basal.closestPrior(to: loopBaseTime)!.value
                let activeOverride = overrideHistory.activeOverride(at: loopBaseTime)

                let basalAdjustment = basal.ifNecessary(
                    at: loopBaseTime,
                    neutralBasalRate: scheduledBasalRate,
                    lastTempBasal: lastTempBasal,
                    continuationInterval: .minutes(11),
                    neutralBasalRateMatchesPump: activeOverride == nil
                )

                recommendation.basalAdjustment = basalAdjustment
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

            logger.default("Loop completed successfully.")
            lastLoopCompleted = Date()
            let duration = lastLoopCompleted!.timeIntervalSince(loopBaseTime)

            analyticsServicesManager.loopDidSucceed(duration)

            dosingDecisionStore.storeDosingDecision(dosingDecision) {}
            NotificationCenter.default.post(name: .LoopCompleted, object: self)

        } catch {
            logger.error("Loop did error: %{public}@", String(describing: error))
            let loopError = error as? LoopError ?? .unknownError(error)
            var dosingDecision = StoredDosingDecision(date: Date(), reason: "loop")
            dosingDecision.appendError(loopError)
            dosingDecisionStore.storeDosingDecision(dosingDecision) {}
            analyticsServicesManager.loopDidError(error: loopError)
        }
        logger.default("Loop ended")
        notify(forChange: .loopFinished)

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

private extension StoredDosingDecision.Settings {
    init?(_ settings: StoredSettings?) {
        guard let settings = settings else {
            return nil
        }
        self.init(syncIdentifier: settings.syncIdentifier)
    }
}


enum CancelActiveTempBasalReason: String {
    case automaticDosingDisabled
    case unreliableCGMData
    case maximumBasalRateChanged
}

protocol LoopDosingManagerProtocol {
    func cancelActiveTempBasal(for reason: CancelActiveTempBasalReason) async

    func loop() async
}

extension LoopDosingManager : LoopDosingManagerProtocol {}
