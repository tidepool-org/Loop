//
//  SelectablePreset.swift
//  Loop
//
//  Created by Pete Schwamb on 3/19/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI
import LoopAlgorithm
import LoopKitUI

enum PresetDuration: Equatable {
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
    var presetDurationType: PresetDuration {
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
        case .activity, .custom, .preset:
            switch duration {
            case .indefinite: return .indefinite
            case .finite: return .scheduled(scheduledEndDate)
            }
        }
    }

    var presetId: String {
        switch context {
        case .preMeal: return "preMeal"
        case .activity: return preset.id
        case .custom: return self.syncIdentifier.uuidString
        case .preset(let preset): return preset.id
        }
    }
}

typealias RangeSafetyClassification = (lower: SafetyClassification, upper: SafetyClassification)

extension PresetDuration: Hashable {
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

    case custom(TemporaryPreset)
    case preMeal(range: ClosedRange<LoopQuantity>)
    case activity(ActivityPreset)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .custom(let preset):
            hasher.combine(preset)
        case .activity(let activity):
            hasher.combine(activity)
        case .preMeal(let range):
            hasher.combine("preMeal")
            hasher.combine(range)
        }
    }

    static func == (lhs: SelectablePreset, rhs: SelectablePreset) -> Bool {
        switch (lhs, rhs) {
        case (.custom(let lhsPreset), .custom(let rhsPreset)):
            return lhsPreset == rhsPreset
        case (.activity(let lhsActivity), .activity(let rhsActivity)):
            return lhsActivity == rhsActivity
        case (.preMeal(let lhsRange), .preMeal(let rhsRange)):
            return lhsRange == rhsRange
        default:
            return false
        }
    }

    var id: String {
        switch self {
        case .custom(let preset): return preset.id
        case .activity(let activity): return "activity-\(activity.id)"
        case .preMeal: return "preMeal"
        }
    }

    var icon: PresetSymbol? {
        switch self {
        case .custom(let preset): return preset.symbol
        case .preMeal: return .image("Pre-Meal-symbol", tint: .preMeal)
        case .activity(let activity): return activity.preset.symbol
        }
    }

    var duration: PresetDuration {
        get {
            switch self {
            case .custom(let preset):
                switch preset.duration {
                case .indefinite:
                    return .indefinite
                case .finite(let duration):
                    return .duration(duration)
                }
            case .activity(let activity):
                switch activity.preset.duration {
                case .indefinite:
                    return .indefinite
                case .finite(let duration):
                    return .duration(duration)
                }
            case .preMeal: return .untilCarbsEntered
            }
        }
        set {
            switch self {
            case .preMeal(let range):
                self = .preMeal(range: range)
            case .activity(var activity):
                activity.preset.settings = TemporaryPresetSettings(targetRange: activity.preset.settings.targetRange, insulinNeedsScaleFactor: activity.preset.settings.insulinNeedsScaleFactor)
                switch newValue {
                case .indefinite:
                    activity.preset.duration = .indefinite
                case .duration(let duration):
                    activity.preset.duration = .finite(duration)
                default:
                    break
                }
                self = .activity(activity)
            case .custom(var preset):
                preset.settings = TemporaryPresetSettings(targetRange: preset.settings.targetRange, insulinNeedsScaleFactor: preset.settings.insulinNeedsScaleFactor)
                switch newValue {
                case .indefinite:
                    preset.duration = .indefinite
                case .duration(let duration):
                    preset.duration = .finite(duration)
                default:
                    break
                }
                self = .custom(preset)
            }
        }
    }

    var isScheduled: Bool {
        return nextScheduledStartAfter(Date()) != nil
    }

    func nextScheduledStartAfter(_ date: Date) -> Date? {
        switch self {
        case .custom(let preset):
            return preset.nextScheduledStartAfter(date)
        case .preMeal, .activity:
            return nil
        }
    }

    var scheduleStartDate: Date? {
        get {
            switch self {
            case .custom(let preset):
                return preset.scheduleStartDate
            case .preMeal, .activity:
                return nil
            }
        }
        set {
            switch self {
            case .custom(var preset):
                preset.scheduleStartDate = newValue
                self = .custom(preset)
            default:
                break
            }
        }
    }

    var repeatOptions: PresetScheduleRepeatOptions {
        get {
            switch self {
            case .custom(let preset):
                return preset.repeatOptions ?? .none
            case .preMeal, .activity:
                return .none
            }
        }
        set {
            switch self {
            case .custom(var preset):
                preset.repeatOptions = newValue
                self = .custom(preset)
            default:
                break
            }
        }
    }


    var name: String {
        get {
            switch self {
            case .custom(let preset): return preset.name
            case .preMeal: return "Pre-Meal"
            case .activity(let activity): return activity.activityType.name
            }
        }
        set {
            switch self {
            case .custom(var preset): preset.name = newValue; self = .custom(preset)
            default: break
            }
        }
    }

    var correctionRange: ClosedRange<LoopQuantity>? {
        get {
            switch self {
            case .custom(let preset): return preset.settings.targetRange
            case .preMeal(let range): return range
            case .activity(let activity): return activity.preset.settings.targetRange
            }
        }

        set {
            switch self {
            case .preMeal:
                self = .preMeal(range: newValue!)
            case .activity(var activity):
                activity.preset.settings = TemporaryPresetSettings(targetRange: newValue, insulinNeedsScaleFactor: activity.preset.settings.insulinNeedsScaleFactor)
                self = .activity(activity)
            case .custom(var preset):
                preset.settings = TemporaryPresetSettings(targetRange: newValue, insulinNeedsScaleFactor: preset.settings.insulinNeedsScaleFactor)
                self = .custom(preset)
            }
        }
    }

    var insulinSensitivityMultiplier: Double? {
        if case .custom(let preset) = self {
            return preset.settings.insulinSensitivityMultiplier
        } else if case .activity(let activity) = self {
            return activity.preset.settings.insulinSensitivityMultiplier
        } else {
            return nil
        }
    }
    
    var insulinNeedsScaleFactor: Double {
        get {
            if case .custom(let preset) = self {
                return 1.0 / (preset.settings.insulinSensitivityMultiplier ?? 1)
            } else if case .activity(let activity) = self {
                return 1.0 / (activity.preset.settings.insulinSensitivityMultiplier ?? 1)
            } else {
                return 1.0
            }
        }
        set {
            if case .activity(var activity) = self {
                activity.preset.settings = TemporaryPresetSettings(targetRange: activity.preset.settings.targetRange, insulinNeedsScaleFactor: newValue)
                self = .activity(activity)
            } else if case .custom(var preset) = self {
                preset.settings = TemporaryPresetSettings(targetRange: preset.settings.targetRange, insulinNeedsScaleFactor: newValue)
                self = .custom(preset)
            }
        }
    }

    var canAdjustSensitivity: Bool {
        switch self {
        case .custom, .activity:
            return true
        case .preMeal:
            return false
        }
    }

    var allowsIndefiniteDuration: Bool {
        switch self {
        case .custom:
            return true
        case .preMeal, .activity:
            return false
        }
    }
    
    var canAdjustDuration: Bool {
        switch self {
        case .custom, .activity:
            return true
        case .preMeal:
            return false
        }
    }

    var canChangeName: Bool {
        switch self {
        case .custom:
            return true
        case .preMeal, .activity:
            return false
        }
    }

    var allowsScheduling: Bool {
        switch self {
        case .custom:
            return true
        case .preMeal, .activity:
            return false
        }
    }

    var canBeDeleted: Bool {
        switch self {
        case .custom:
            return true
        case .preMeal, .activity:
            return false
        }
    }

    var isPreMeal: Bool {
        if case .preMeal = self {
            return true
        }
        return false
    }

    var dateCreated: Date {
        switch self {
        case .custom:
            return .distantPast // TODO
        case .preMeal:
            return .distantPast.addingTimeInterval(1)
        case .activity:
            return .distantPast
        }
    }

    func title(font: Font, iconSize: Double, colorPalette: LoopUIColorPalette) -> some View {
        HStack(spacing: 6) {
            if let icon, !icon.isEmpty {
                PresetSymbolView(icon)
            }

            Text(name)
                .font(font)
                .fontWeight(.semibold)
        }
    }
}
