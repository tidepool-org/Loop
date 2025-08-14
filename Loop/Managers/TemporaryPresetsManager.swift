//
//  TemporaryPresetsManager.swift
//  Loop
//
//  Created by Pete Schwamb on 11/1/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import os.log
import LoopCore


protocol PresetActivationObserver: AnyObject {
    func presetActivated(context: TemporaryScheduleOverride.Context, duration: TemporaryScheduleOverride.Duration)
    func presetDeactivated(context: TemporaryScheduleOverride.Context)
}

@MainActor
@Observable
class TemporaryPresetsManager {

    @ObservationIgnored private let log = OSLog(category: "TemporaryPresetsManager")

    let managerIdentifier = "TemporaryPresetsManager"

    @ObservationIgnored private var settingsProvider: SettingsProvider

    var presetHistory: TemporaryScheduleOverrideHistory

    @ObservationIgnored private var alertIssuer: AlertIssuer?

    @ObservationIgnored private var presetActivationObservers: [PresetActivationObserver] = []

    @ObservationIgnored private var overrideIntentObserver: NSKeyValueObservation? = nil

    init(settingsProvider: SettingsProvider, alertIssuer: AlertIssuer? = nil, presetHistory: TemporaryScheduleOverrideHistory? = nil) {
        self.settingsProvider = settingsProvider
        self.alertIssuer = alertIssuer

        self.presetHistory = presetHistory ?? TemporaryScheduleOverrideHistoryContainer.shared.fetch()
        TemporaryScheduleOverrideHistory.relevantTimeWindow = Bundle.main.localCacheDuration

        _scheduleOverride = self.presetHistory.activeOverride(at: Date())

        if scheduleOverride?.context == .preMeal {
            preMealOverride = scheduleOverride
            scheduleOverride = nil
        }

        overrideIntentObserver = UserDefaults.appGroup?.observe(
            \.intentExtensionOverrideToSet,
             options: [.new],
             changeHandler:
                { [weak self] (defaults, change) in
                    Task { @MainActor in
                        self?.handleIntentOverrideAction(default: defaults, change: change)
                    }
                }
        )
    }

    private func handleIntentOverrideAction(default: UserDefaults, change: NSKeyValueObservedChange<String?>) {
        guard let name = change.newValue??.lowercased(),
              let appGroup = UserDefaults.appGroup else 
        {
            return
        }

        guard let preset = settingsProvider.settings.overridePresets.first(where: {$0.name.lowercased() == name}) else
        {
            log.error("Override Intent: Unable to find override named '%s'", String(describing: name))
            return
        }

        log.default("Override Intent: setting override named '%s'", String(describing: name))
        scheduleOverride = preset.createOverride(enactTrigger: .remote("Siri"))

        // Remove the override from UserDefaults so we don't set it multiple times
        appGroup.intentExtensionOverrideToSet = nil
    }

    public func addTemporaryPresetObserver(_ observer: PresetActivationObserver) {
        presetActivationObservers.append(observer)
    }

    public var scheduleOverride: TemporaryScheduleOverride? {
        didSet {
            guard oldValue != scheduleOverride else {
                return
            }

            if scheduleOverride != nil {
                preMealOverride = nil
            }
            
            if scheduleOverride != oldValue {
                presetHistory.recordOverride(scheduleOverride)

                if let oldPreset = oldValue {
                    for observer in self.presetActivationObservers {
                        observer.presetDeactivated(context: oldPreset.context)
                    }
                }
                if let newPreset = scheduleOverride {
                    for observer in self.presetActivationObservers {
                        observer.presetActivated(context: newPreset.context, duration: newPreset.duration)
                    }
                    
                    scheduleClearOverride(override: newPreset)
                }
            }

            notify(forChange: .preferences)
        }
    }

    public var preMealOverride: TemporaryScheduleOverride? {
        didSet {
            guard oldValue != preMealOverride else {
                return
            }
            
            if let newValue = preMealOverride, newValue.context != .preMeal || newValue.settings.insulinNeedsScaleFactor != nil {
                preconditionFailure("The `preMealOverride` field should be used only for a pre-meal target range override")
            }
            
            if preMealOverride != nil {
                scheduleOverride = nil
            }
            
            presetHistory.recordOverride(preMealOverride)

            if let newPreset = preMealOverride {
                for observer in self.presetActivationObservers {
                    observer.presetActivated(context: newPreset.context, duration: newPreset.duration)
                }
                
                scheduleClearOverride(override: newPreset)
            }
            
            notify(forChange: .preferences)
        }
    }
    
    public var activeOverride: TemporaryScheduleOverride? {
        let override = (preMealOverride ?? scheduleOverride)
        if override?.isActive() == true {
            return override
        } else {
            return nil
        }
    }

    public var activePreset: SelectablePreset? {
        guard let override = activeOverride else {
            return nil
        }

        let range = override.settings.targetRange

        switch override.context {
        case .preMeal:
            return .preMeal(range: range!)
        case .legacyWorkout:
            return .legacyWorkout(range: range!, duration: override.duration.presetDurationType)
        case .custom:
            let preset = TemporaryPreset(
                id: override.syncIdentifier,
                symbol: "",
                name: "Single Use Preset",
                settings: override.settings,
                duration: override.duration
            )
            return .custom(preset)
        case .preset(let preset):
            return .custom(preset)
        }
    }

    var selectablePresets: [SelectablePreset] {
        var presets: [SelectablePreset] = []

        let settings = settingsProvider.settings

        if let activeOverride, activeOverride.context == .custom {
            presets.append(activePreset!)
        }

        if let preMealTargetRange = settings.preMealTargetRange {
            presets.append(.preMeal(range: preMealTargetRange))
        }

        if let legacyWorkoutTargetRange = settings.workoutTargetRange {
            let duration = settings.workoutDefaultDuration ?? .indefinite
            presets.append(.legacyWorkout(
                range: legacyWorkoutTargetRange,
                duration: duration.presetDurationType
            ))
        }

        presets.append(contentsOf: settings.overridePresets.map { .custom($0)} )

        return presets
    }



    var clearOverrideTimer: Timer?
    public func scheduleClearOverride(override: TemporaryScheduleOverride) {
        clearOverrideTimer?.invalidate()
        if override.duration.isInfinite { return }
        log.default("Scheduling override end timer %{public}@", String(describing: override))

        clearOverrideTimer = Timer.scheduledTimer(withTimeInterval: override.scheduledEndDate.timeIntervalSince(Date()), repeats: false, block: { [weak self] _ in
            Task {
                self?.log.default("override end timer fired for %{public}@", String(describing: override))
                await self?.endOverride(override)
            }
        })
    }

    func endOverride(_ override: TemporaryScheduleOverride) {
        if override == scheduleOverride {
            clearOverride()
        } else if override == preMealOverride {
            clearOverride(matching: .preMeal)
        }
    }

    public var isScheduleOverrideInfiniteWorkout: Bool {
        guard let scheduleOverride = scheduleOverride else { return false }
        return scheduleOverride.context == .legacyWorkout && scheduleOverride.duration.isInfinite
    }

    public func effectiveGlucoseTargetRangeSchedule(presumingMealEntry: Bool = false) -> GlucoseRangeSchedule?  {

        guard let glucoseTargetRangeSchedule = settingsProvider.settings.glucoseTargetRangeSchedule else {
            return nil
        }

        let preMealOverride = presumingMealEntry ? nil : self.preMealOverride

        let currentEffectiveOverride: TemporaryScheduleOverride?
        switch (preMealOverride, scheduleOverride) {
        case (let preMealOverride?, nil):
            currentEffectiveOverride = preMealOverride
        case (nil, let scheduleOverride?):
            currentEffectiveOverride = scheduleOverride
        case (let preMealOverride?, let scheduleOverride?):
            currentEffectiveOverride = preMealOverride.scheduledEndDate > Date()
                ? preMealOverride
                : scheduleOverride
        case (nil, nil):
            currentEffectiveOverride = nil
        }

        if let effectiveOverride = currentEffectiveOverride {
            return glucoseTargetRangeSchedule.applyingOverride(effectiveOverride)
        } else {
            return glucoseTargetRangeSchedule
        }
    }

    public func isScheduleOverrideActive(at date: Date = Date()) -> Bool {
        return scheduleOverride?.isActive(at: date) == true
    }

    public func isNonPreMealOverrideActive(at date: Date = Date()) -> Bool {
        return isScheduleOverrideActive(at: date) == true && scheduleOverride?.context != .preMeal
    }

    public func isPreMealTargetActive(at date: Date = Date()) -> Bool {
        return isScheduleOverrideActive(at: date) == true && scheduleOverride?.context == .preMeal
    }

    public func futureOverrideEnabled(relativeTo date: Date = Date()) -> Bool {
        guard let scheduleOverride = scheduleOverride else { return false }
        return scheduleOverride.startDate > date
    }

    public func enablePreMealOverride(at date: Date = Date(), for duration: TimeInterval) {
        preMealOverride = makePreMealOverride(beginningAt: date, for: duration)
    }

    private func makePreMealOverride(beginningAt date: Date = Date(), for duration: TimeInterval) -> TemporaryScheduleOverride? {
        guard let preMealTargetRange = settingsProvider.settings.preMealTargetRange else {
            return nil
        }
        return TemporaryScheduleOverride(
            context: .preMeal,
            settings: TemporaryPresetSettings(targetRange: preMealTargetRange),
            startDate: date,
            duration: .finite(duration),
            enactTrigger: .local,
            syncIdentifier: UUID()
        )
    }

    public func enableLegacyWorkoutOverride(at date: Date = Date(), for duration: TemporaryScheduleOverride.Duration) {
        scheduleOverride = legacyWorkoutOverride(beginningAt: date, for: duration)
        preMealOverride = nil
    }

    public func legacyWorkoutOverride(beginningAt date: Date = Date(), for duration: TemporaryScheduleOverride.Duration) -> TemporaryScheduleOverride? {
        guard let legacyWorkoutTargetRange = settingsProvider.settings.workoutTargetRange else {
            return nil
        }

        return TemporaryScheduleOverride(
            context: .legacyWorkout,
            settings: TemporaryPresetSettings(targetRange: legacyWorkoutTargetRange),
            startDate: date,
            duration: duration,
            enactTrigger: .local,
            syncIdentifier: UUID()
        )
    }

    func startPreset(withIdentifier identifier: String) {
        guard let preset = selectablePresets.first(where: { $0.id == identifier }) else {
            log.error("Unable to find preset with identifier ${public}@", identifier)
            return
        }
        startPreset(preset)
    }


    func startPreset(_ preset: SelectablePreset) {
        switch preset {
        case .custom(let temporaryScheduleOverridePreset):
            scheduleOverride = temporaryScheduleOverridePreset.createOverride(enactTrigger: .local)
        case .preMeal:
            enablePreMealOverride(for: .hours(1))
        case .legacyWorkout(_, let duration):
            enableLegacyWorkoutOverride(for: duration.presetDuration)
        }
    }

    func endPreset() {
        if activeOverride?.context == .preMeal {
            clearOverride(matching: .preMeal)
        } else {
            clearOverride()
        }
    }

    public func endPreMealOverride() {
        preMealOverride?.scheduledEndDate = .now
        clearOverride(matching: .preMeal)
    }

    public func clearOverride(matching context: TemporaryScheduleOverride.Context? = nil) {
        if context == .preMeal {
            preMealOverride = nil
            return
        }

        guard let scheduleOverride = scheduleOverride else { return }

        if let context = context {
            if scheduleOverride.context == context {
                self.scheduleOverride = nil
            }
        } else {
            self.scheduleOverride = nil
        }
    }

    public var basalRateScheduleApplyingOverrideHistory: BasalRateSchedule? {
        if let basalSchedule = settingsProvider.settings.basalRateSchedule {
            return presetHistory.resolvingRecentBasalSchedule(basalSchedule)
        } else {
            return nil
        }
    }

    /// The insulin sensitivity schedule, applying recent overrides relative to the current moment in time.
    public var insulinSensitivityScheduleApplyingOverrideHistory: InsulinSensitivitySchedule? {
        if let insulinSensitivitySchedule = settingsProvider.settings.insulinSensitivitySchedule {
            return presetHistory.resolvingRecentInsulinSensitivitySchedule(insulinSensitivitySchedule)
        } else {
            return nil
        }
    }

    public var carbRatioScheduleApplyingOverrideHistory: CarbRatioSchedule? {
        if let carbRatioSchedule = carbRatioSchedule {
            return presetHistory.resolvingRecentCarbRatioSchedule(carbRatioSchedule)
        } else {
            return nil
        }
    }

    private func notify(forChange context: LoopUpdateContext) {
        NotificationCenter.default.post(name: .LoopDataUpdated,
            object: self,
            userInfo: [
                LoopDataManager.LoopUpdateContextKey: context.rawValue
            ]
        )
    }

    func updateActivePresetDuration(newEndDate: Date) {
        if var scheduleOverride {
            if newEndDate > Date() {
                scheduleOverride.scheduledEndDate = newEndDate
            } else {
                scheduleOverride.scheduledEndDate = newEndDate.addingTimeInterval(.days(1))
            }
            
            self.scheduleOverride = scheduleOverride
            self.scheduleClearOverride(override: scheduleOverride)
        }
    }

    var lastUsed: [String: Date]?

    func lastUsed(id: String) -> Date? {
        if lastUsed == nil {
            let enacts = presetHistory.getOverrideHistory(startDate: .distantPast, endDate: Date())
            lastUsed = [:]
            for enact in enacts {
                var id: String
                switch enact.context {
                    case .preMeal: id = "preMeal"
                    case .legacyWorkout: id = "legacyWorkout"
                    case .preset(let preset): id = preset.id.uuidString
                    case .custom: continue
                }
                lastUsed![id] = max(lastUsed![id] ?? .distantPast, enact.startDate)
            }
        }
        return lastUsed![id]
    }

    func scheduleNextPresetReminder() async {

        let settings = settingsProvider.settings

        let now = Date()

        let preset = settings.overridePresets.reduce(into: nil as TemporaryPreset?) { result, preset in
            if let nextScheduledTime = preset.nextScheduledStartAfter(now) {
                if result == nil || nextScheduledTime < (result!.nextScheduledStartAfter(now)!) {
                    result = preset
                }
            }
        }

        if let preset {

            let nextScheduledPresetReminderIdentifier = Alert.Identifier(managerIdentifier: managerIdentifier, alertIdentifier: preset.id.uuidString)
            await alertIssuer?.retractAlert(identifier: nextScheduledPresetReminderIdentifier)


            let nextScheduledTime = preset.nextScheduledStartAfter(now)!

            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short

            let title = NSLocalizedString("Start Scheduled Preset?", comment: "Scheduled preset reminder title")
            let body = String(
                format: NSLocalizedString("Your %1$@ preset is scheduled for today at %2$@. Would you like to start it now?\n\nThis will end any active preset.", comment: "Scheduled preset reminder alert body. (1: preset name) (2: time)"),
                preset.name,
                formatter.string(
                    from: nextScheduledTime
                )
            )

            let actions = [
                Alert.UserAlertAction(
                    label: NSLocalizedString("Don't Start", comment: "Label for do not start preset action on scheduled preset reminder alert"),
                    identifier: "acknowledge",
                    style: .default
                ),
                Alert.UserAlertAction(
                    label: NSLocalizedString("Yes, Start Now", comment: "Label for do yes, start preset now action on scheduled preset reminder alert"),
                    identifier: "startPreset",
                    style: .cancel
                )
            ]

            let content = Alert.Content(title: title,
                                        body: body,
                                        actions: actions)

            let metadata: Alert.Metadata = ["presetId": Alert.MetadataValue(preset.id.uuidString)]

            let alert = Alert(
                identifier: nextScheduledPresetReminderIdentifier,
                foregroundContent: content,
                backgroundContent: content,
                trigger: .delayed(interval: nextScheduledTime.timeIntervalSince(now)),
                interruptionLevel: .timeSensitive,
                metadata: metadata,
                categoryIdentifier: LoopNotificationCategory.presetReminder.rawValue
            )

            await alertIssuer?.issueAlert(alert)
        }
    }

}

extension TemporaryPresetsManager {
    static var placeholder: TemporaryPresetsManager {
        .init(settingsProvider: SettingsManager.placeholder)
    }
}

extension TemporaryPresetsManager : AlertResponder {
    func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier) async throws { }

    func handleAlertAction(actionIdentifier: String, from alert: Alert) async throws {
        if actionIdentifier == NotificationManager.Action.startPreset.rawValue,
           let metdata = alert.metadata,
           let presetIdentifier = metdata["presetId"]?.wrapped as? String?
        {
            startPreset(withIdentifier: presetIdentifier!)
        } else {
            log.error("Could not identify preset to activate for alert action: actionIdentifier=%{public}@, alert=%{public}@", actionIdentifier, String(describing: alert))
        }
    }
}

@MainActor
public protocol SettingsWithOverridesProvider {
    var insulinSensitivityScheduleApplyingOverrideHistory: InsulinSensitivitySchedule? { get }
    var carbRatioSchedule: CarbRatioSchedule? { get }
    var maximumBolus: Double? { get }
}

extension TemporaryPresetsManager : SettingsWithOverridesProvider {
    var carbRatioSchedule: LoopKit.CarbRatioSchedule? {
        settingsProvider.settings.carbRatioSchedule
    }

    var maximumBolus: Double? {
        settingsProvider.settings.maximumBolus
    }
}
