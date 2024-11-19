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

enum SelectablePreset: Hashable, Identifiable {
    var id: Self { self }

    case custom(TemporaryScheduleOverridePreset)
    case preMeal(ClosedRange<HKQuantity>)
    case legacyWorkout(ClosedRange<HKQuantity>)

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
            case .legacyWorkout: return "Legacy Workout"
        }
    }

    var correctionRange: ClosedRange<HKQuantity>? {
        switch self {
            case .custom(let preset): return preset.settings.targetRange
            case .preMeal(let range): return range
            case .legacyWorkout(let range): return range
        }
    }

    var insulinSensitivityMultiplier: Double? {
        if case .custom(let preset) = self {
            return preset.settings.insulinSensitivityMultiplier
        } else {
            return nil
        }
    }
}

class PresetsViewModel: ObservableObject {
    
    // MARK: Training
    @AppStorage("hasCompletedPresetsTraining") var hasCompletedTraining: Bool = false
    @Published var showTraining: Bool = false

    var correctionRangeOverrides: CorrectionRangeOverrides?

    @Published var customPresets: [TemporaryScheduleOverridePreset]

    var allPresets: [SelectablePreset] {
        var presets: [SelectablePreset] = []

        if let preMealTargetRange = correctionRangeOverrides?.preMeal {
            presets.append(.preMeal(preMealTargetRange))
        }

        if let legacyWorkoutTargetRange = correctionRangeOverrides?.workout {
            presets.append(.legacyWorkout(legacyWorkoutTargetRange))
        }

        presets.append(contentsOf: customPresets.map { .custom($0)} )

        return presets
    }

    init(customPresets: [TemporaryScheduleOverridePreset], correctionRangeOverrides: CorrectionRangeOverrides?) {
        self.customPresets = customPresets
        self.correctionRangeOverrides = correctionRangeOverrides
    }
}
