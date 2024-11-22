//
//  PresetsViewModel.swift
//  Loop
//
//  Created by Cameron Ingham on 10/23/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

enum PresetDurationType {
    case untilCarbsEntered
    case duration(TimeInterval)
    case indefinite
}

enum PresetIcon {
    case emoji(String)
    case image(String, Color)
}

typealias RangeSafetyClassification = (lower: SafetyClassification, upper: SafetyClassification)

enum SelectablePreset: Hashable, Identifiable {

    func hash(into hasher: inout Hasher) {
        switch self {
        case .custom(let preset):
            hasher.combine(preset)
        case .legacyWorkout(let range, _):
            hasher.combine("legacy")
            hasher.combine(range)
        case .preMeal(let range, _):
            hasher.combine("premeal")
            hasher.combine(range)
        }
    }

    static func == (lhs: SelectablePreset, rhs: SelectablePreset) -> Bool {
        switch (lhs, rhs) {
        case (.custom(let lhsPreset), .custom(let rhsPreset)):
            return lhsPreset == rhsPreset
        case (.legacyWorkout(let lhsRange, _), .legacyWorkout(let rhsRange, _)):
            return lhsRange == rhsRange
        case (.preMeal(let lhsRange, _), .legacyWorkout(let rhsRange, _)):
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
    case preMeal(range: ClosedRange<HKQuantity>, guardrail: Guardrail<HKQuantity>?)
    case legacyWorkout(range: ClosedRange<HKQuantity>, guardrail: Guardrail<HKQuantity>?)

    var icon: PresetIcon {
        switch self {
        case .custom(let preset): return .emoji(preset.symbol)
        case .preMeal: return .image("Pre-Meal", .carbTintColor)
        case .legacyWorkout: return .image("workout", .insulinTintColor)
        }
    }

    var duration: PresetDurationType {
        switch self {
        case .custom(let preset):
            switch preset.duration {
            case .indefinite:
                return .indefinite
            case .finite(let duration):
                return .duration(duration)
            }
        case .preMeal: return .untilCarbsEntered
        case .legacyWorkout: return .indefinite
        }
    }

    var name: String {
        switch self {
            case .custom(let preset): return preset.name
            case .preMeal: return "Pre-Meal"
            case .legacyWorkout: return "Workout"
        }
    }

    var correctionRange: ClosedRange<HKQuantity>? {
        switch self {
        case .custom(let preset): return preset.settings.targetRange
        case .preMeal(let range, _): return range
        case .legacyWorkout(let range, _): return range
        }
    }

    var insulinSensitivityMultiplier: Double? {
        if case .custom(let preset) = self {
            return preset.settings.insulinSensitivityMultiplier
        } else {
            return nil
        }
    }

    var guardrail: Guardrail<HKQuantity>? {
        switch self {
        case .custom:
            return nil
        case .preMeal(_, let guardrail):
            return guardrail
        case .legacyWorkout(_, let guardrail):
            return guardrail
        }
    }
}

class PresetsViewModel: ObservableObject {

    // MARK: Training
    @AppStorage("hasCompletedPresetsTraining") var hasCompletedTraining: Bool = false
    @Published var showTraining: Bool = false

    var correctionRangeOverrides: CorrectionRangeOverrides?

    @Published var customPresets: [TemporaryScheduleOverridePreset]

    let preMealGuardrail: Guardrail<HKQuantity>?
    let legacyWorkoutGuardrail: Guardrail<HKQuantity>?

    var allPresets: [SelectablePreset] {
        var presets: [SelectablePreset] = []

        if let preMealTargetRange = correctionRangeOverrides?.preMeal {
            presets.append(.preMeal(
                range: preMealTargetRange,
                guardrail: preMealGuardrail
            ))
        }

        if let legacyWorkoutTargetRange = correctionRangeOverrides?.workout {
            presets.append(.legacyWorkout(
                range: legacyWorkoutTargetRange,
                guardrail: legacyWorkoutGuardrail
            ))
        }

        presets.append(contentsOf: customPresets.map { .custom($0)} )

        return presets
    }

    init(
        customPresets: [TemporaryScheduleOverridePreset],
        correctionRangeOverrides: CorrectionRangeOverrides?,
        preMealGuardrail: Guardrail<HKQuantity>?,
        legacyWorkoutGuardrail: Guardrail<HKQuantity>?
    ) {
        self.customPresets = customPresets
        self.correctionRangeOverrides = correctionRangeOverrides
        self.preMealGuardrail = preMealGuardrail
        self.legacyWorkoutGuardrail = legacyWorkoutGuardrail
    }

}
