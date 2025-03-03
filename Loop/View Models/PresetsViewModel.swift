//
//  PresetsViewModel.swift
//  Loop
//
//  Created by Cameron Ingham on 10/23/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKit

enum PresetDurationType: Equatable {
    case untilCarbsEntered
    case duration(TimeInterval)
    case indefinite

    var presetDuration: TemporaryScheduleOverride.Duration {
        switch self {
        case .indefinite: return .indefinite
        case .duration(let duration): return .finite(duration)
        case .untilCarbsEntered: return .indefinite
        }
    }
}

enum PresetExpectedEndTime {
    case untilCarbsEntered
    case scheduled(Date)
    case indefinite
}

extension TemporaryScheduleOverride.Duration {
    var presetDurationType: PresetDurationType {
        switch self {
        case .finite(let interval):
            return .duration(interval)
        case .indefinite:
            return .indefinite
        }
    }
}

extension TemporaryScheduleOverride {
    var expectedEndTime: PresetExpectedEndTime? {
        switch context {
        case .preMeal: return .untilCarbsEntered
        case .legacyWorkout, .custom, .preset:
            switch duration {
            case .indefinite: return .indefinite
            case .finite: return .scheduled(scheduledEndDate)
            }
        }
    }

    var presetId: String {
        switch context {
        case .preMeal: return "preMeal"
        case .legacyWorkout: return "legacyWorkout"
        case .custom: return self.syncIdentifier.uuidString
        case .preset(let preset): return preset.id.uuidString
        }
    }
}

enum PresetIcon {
    case emoji(String)
    case image(String, Color)
}

typealias RangeSafetyClassification = (lower: SafetyClassification, upper: SafetyClassification)

extension PresetDurationType: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .indefinite:
            hasher.combine("indefinite")
        case .untilCarbsEntered:
            hasher.combine("untilCarbsEntered")
        case .duration(let interval):
            hasher.combine("duration")
            hasher.combine(interval)
        }
    }
}

enum SelectablePreset: Hashable, Identifiable {

    func hash(into hasher: inout Hasher) {
        switch self {
        case .custom(let preset):
            hasher.combine(preset)
        case .legacyWorkout(let range, let duration, _):
            hasher.combine("legacyWorkout")
            hasher.combine(range)
            hasher.combine(duration)
        case .preMeal(let range, _):
            hasher.combine("preMeal")
            hasher.combine(range)
        }
    }

    static func == (lhs: SelectablePreset, rhs: SelectablePreset) -> Bool {
        switch (lhs, rhs) {
        case (.custom(let lhsPreset), .custom(let rhsPreset)):
            return lhsPreset == rhsPreset
        case (.legacyWorkout(let lhsRange, let lhsDuration, _), .legacyWorkout(let rhsRange, let rhsDuration, _)):
            return lhsRange == rhsRange && lhsDuration == rhsDuration
        case (.preMeal(let lhsRange, _), .preMeal(let rhsRange, _)):
            return lhsRange == rhsRange
        default:
            return false
        }
    }
    
    var id: String {
        switch self {
        case .custom(let preset): return preset.id.uuidString
        case .legacyWorkout: return "legacyWorkout"
        case .preMeal: return "preMeal"
        }
    }

    case custom(TemporaryScheduleOverridePreset)
    case preMeal(range: ClosedRange<LoopQuantity>, guardrail: Guardrail<LoopQuantity>)
    case legacyWorkout(range: ClosedRange<LoopQuantity>, duration: PresetDurationType, guardrail: Guardrail<LoopQuantity>)

    var icon: PresetIcon {
        switch self {
        case .custom(let preset): return .emoji(preset.symbol)
        case .preMeal: return .image("Pre-Meal", .carbTintColor)
        case .legacyWorkout: return .image("workout", .glucoseTintColor)
        }
    }

    var duration: PresetDurationType {
        get {
            switch self {
            case .custom(let preset):
                switch preset.duration {
                case .indefinite:
                    return .indefinite
                case .finite(let duration):
                    return .duration(duration)
                }
            case .preMeal: return .untilCarbsEntered
            case .legacyWorkout(_, let duration, _):
                return duration
            }
        }
        set {
            switch self {
            case .preMeal(let range, let guardrail):
                self = .preMeal(range: range, guardrail: guardrail)
            case .legacyWorkout(let range, _, let guardrail):
                self = .legacyWorkout(range: range, duration: newValue, guardrail: guardrail)
            case .custom(var preset):
                preset.settings = TemporaryScheduleOverrideSettings(targetRange: preset.settings.targetRange, insulinNeedsScaleFactor: preset.settings.insulinNeedsScaleFactor)
            }
        }
    }

    var name: String {
        switch self {
            case .custom(let preset): return preset.name
            case .preMeal: return "Pre-Meal"
            case .legacyWorkout: return "Workout"
        }
    }

    var correctionRange: ClosedRange<LoopQuantity>? {
        get {
            switch self {
            case .custom(let preset): return preset.settings.targetRange
            case .preMeal(let range, _): return range
            case .legacyWorkout(let range, _, _): return range
            }
        }

        set {
            switch self {
            case .preMeal(_, let guardrail):
                self = .preMeal(range: newValue!, guardrail: guardrail)
            case .legacyWorkout(_, let duration, let guardrail):
                self = .legacyWorkout(range: newValue!, duration: duration, guardrail: guardrail)
            case .custom(var preset):
                preset.settings = TemporaryScheduleOverrideSettings(targetRange: newValue, insulinNeedsScaleFactor: preset.settings.insulinNeedsScaleFactor)
            }
        }
    }

    var insulinSensitivityMultiplier: Double? {
        if case .custom(let preset) = self {
            return preset.settings.insulinSensitivityMultiplier
        } else {
            return nil
        }
    }

    var canAdjustSensitivity: Bool {
        switch self {
        case .custom:
            return true
        case .preMeal:
            return false
        case .legacyWorkout:
            return false
        }
    }

    var canAdjustDuration: Bool {
        switch self {
        case .custom:
            return true;
        case .preMeal:
            return false;
        case .legacyWorkout:
            return true;
        }
    }

    var isPreMeal: Bool {
        if case .preMeal = self {
            return true
        }
        return false
    }

    var guardrail: Guardrail<LoopQuantity> {
        switch self {
        case .custom:
            return Guardrail.correctionRange
        case .preMeal(_, let guardrail):
            return guardrail
        case .legacyWorkout(_, _, let guardrail):
            return guardrail
        }
    }

    var dateCreated: Date {
        switch self {
        case .custom:
            return .distantPast // TODO
        case .preMeal:
            return .distantPast.addingTimeInterval(1)
        case .legacyWorkout:
            return .distantPast
        }
    }
    
    func title(font: Font, iconSize: Double) -> some View {
        HStack(spacing: 6) {
            switch icon {
            case .emoji(let emoji):
                Text(emoji)
            case .image(let name, let iconColor):
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(iconColor)
                    .frame(width: UIFontMetrics.default.scaledValue(for: iconSize), height: UIFontMetrics.default.scaledValue(for: iconSize))
            }

            Text(name)
                .font(font)
                .fontWeight(.semibold)
        }
    }
}

@MainActor
@Observable
public class PresetsViewModel {

    // MARK: Training
    
    // This double property is needed to allow AppStorage to be observed
    @ObservationIgnored @AppStorage("hasCompletedPresetsTraining") private var _hasCompletedTraining: Bool = false
    @ObservationIgnored
    var hasCompletedTraining: Bool {
        get {
            access(keyPath: \.hasCompletedTraining)
            return _hasCompletedTraining
        }
        set {
            withMutation(keyPath: \.hasCompletedTraining) {
                _hasCompletedTraining = newValue
            }
        }
    }
    
    // This double property is needed to allow AppStorage to be observed
    @ObservationIgnored @AppStorage("presetsSortOrder") private var _selectedSortOption: PresetSortOption = .name
    @ObservationIgnored
    var selectedSortOption: PresetSortOption {
        get {
            access(keyPath: \.selectedSortOption)
            return _selectedSortOption
        }
        set {
            withMutation(keyPath: \.selectedSortOption) {
                _selectedSortOption = newValue
            }
        }
    }
    
    // This double property is needed to allow AppStorage to be observed
    @ObservationIgnored @AppStorage("presetsSortDirectionReversed") private var _presetsSortAscending: Bool = true
    @ObservationIgnored
    var presetsSortAscending: Bool {
        get {
            access(keyPath: \.selectedSortOption)
            return _presetsSortAscending
        }
        set {
            withMutation(keyPath: \.selectedSortOption) {
                _presetsSortAscending = newValue
            }
        }
    }

    @ObservationIgnored var premealRange: ClosedRange<LoopQuantity>?
    @ObservationIgnored var workoutRange: ClosedRange<LoopQuantity>?
    @ObservationIgnored var workoutDuration: TemporaryScheduleOverride.Duration

    let temporaryPresetsManager: TemporaryPresetsManager

    var customPresets: [TemporaryScheduleOverridePreset]
    var pendingPreset: SelectablePreset?
    var editPreset: [String] = []

    public private(set) var preMealGuardrail: Guardrail<LoopQuantity>
    public private(set) var legacyWorkoutGuardrail: Guardrail<LoopQuantity>

    private var presetHistory: TemporaryScheduleOverrideHistory

    var scheduledRange: ClosedRange<LoopQuantity>

    var activeOverride: TemporaryScheduleOverride? {
        temporaryPresetsManager.preMealOverride ?? temporaryPresetsManager.scheduleOverride
    }

    var activePreset: SelectablePreset? {
        return allPresets.first(where: { $0.id == temporaryPresetsManager.activeOverride?.presetId })
    }

    var allPresets: [SelectablePreset] {
        var presets: [SelectablePreset] = []

        if let preMealTargetRange = premealRange {
            presets.append(.preMeal(
                range: preMealTargetRange,
                guardrail: preMealGuardrail
            ))
        }

        if let legacyWorkoutTargetRange = workoutRange {
            presets.append(.legacyWorkout(
                range: legacyWorkoutTargetRange,
                duration: workoutDuration.presetDurationType,
                guardrail: legacyWorkoutGuardrail
            ))
        }

        presets.append(contentsOf: customPresets.map { .custom($0)} )

        return presets
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

    var presetWasEdited: ((SelectablePreset) throws -> Void)?;

    init(
        customPresets: [TemporaryScheduleOverridePreset],
        premealRange: ClosedRange<LoopQuantity>?,
        workoutRange: ClosedRange<LoopQuantity>?,
        workoutDuration: TemporaryScheduleOverride.Duration,
        presetsHistory: TemporaryScheduleOverrideHistory,
        preMealGuardrail: Guardrail<LoopQuantity>,
        legacyWorkoutGuardrail: Guardrail<LoopQuantity>,
        temporaryPresetsManager: TemporaryPresetsManager,
        scheduledRange: ClosedRange<LoopQuantity>
    ) {
        self.customPresets = customPresets
        self.premealRange = premealRange
        self.workoutRange = workoutRange
        self.workoutDuration = workoutDuration
        self.presetHistory = presetsHistory
        self.preMealGuardrail = preMealGuardrail
        self.legacyWorkoutGuardrail = legacyWorkoutGuardrail
        self.temporaryPresetsManager = temporaryPresetsManager
        self.scheduledRange = scheduledRange
    }

    func savePreset(_ preset: SelectablePreset) {
        try? presetWasEdited?(preset);

        switch preset {
        case .preMeal(let range, _):
            self.premealRange = range;
        case .legacyWorkout(let range, let duration, _):
            self.workoutRange = range;
            self.workoutDuration = duration.presetDuration;
        default:
            break
        }
    }

    func startPreset(_ preset: SelectablePreset) {
        switch preset {
        case .custom(let temporaryScheduleOverridePreset):
            temporaryPresetsManager.scheduleOverride = temporaryScheduleOverridePreset.createOverride(enactTrigger: .local)
        case .preMeal:
            temporaryPresetsManager.enablePreMealOverride(for: .hours(1))
        case .legacyWorkout(_, let duration, _):
            temporaryPresetsManager.enableLegacyWorkoutOverride(for: duration.presetDuration)
        }
    }
    
    func endPreset() {
        if case .preMeal(_, _) = activePreset {
            temporaryPresetsManager.clearOverride(matching: .preMeal)
        } else {
            temporaryPresetsManager.clearOverride()
        }
    }
    
    func updateActivePresetDuration(newEndDate: Date) {
        temporaryPresetsManager.updateActiveOverrideDuration(newEndDate: newEndDate)
    }
}
