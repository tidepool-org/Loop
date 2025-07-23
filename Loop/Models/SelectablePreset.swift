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

enum PresetIcon: Hashable {
    case emoji(String)
    case image(String, Color)
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
    case legacyWorkout(range: ClosedRange<LoopQuantity>, duration: PresetDuration)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .custom(let preset):
            hasher.combine(preset)
        case .legacyWorkout(let range, let duration):
            hasher.combine("legacyWorkout")
            hasher.combine(range)
            hasher.combine(duration)
        case .preMeal(let range):
            hasher.combine("preMeal")
            hasher.combine(range)
        }
    }

    static func == (lhs: SelectablePreset, rhs: SelectablePreset) -> Bool {
        switch (lhs, rhs) {
        case (.custom(let lhsPreset), .custom(let rhsPreset)):
            return lhsPreset == rhsPreset
        case (.legacyWorkout(let lhsRange, let lhsDuration), .legacyWorkout(let rhsRange, let rhsDuration)):
            return lhsRange == rhsRange && lhsDuration == rhsDuration
        case (.preMeal(let lhsRange), .preMeal(let rhsRange)):
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

    var icon: PresetIcon {
        switch self {
        case .custom(let preset): return .emoji(preset.symbol)
        case .preMeal: return .image("Pre-Meal", .carbTintColor)
        case .legacyWorkout: return .image("workout", .glucoseTintColor)
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
            case .preMeal: return .untilCarbsEntered
            case .legacyWorkout(_, let duration):
                return duration
            }
        }
        set {
            switch self {
            case .preMeal(let range):
                self = .preMeal(range: range)
            case .legacyWorkout(let range, _):
                self = .legacyWorkout(range: range, duration: newValue)
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
        case .preMeal, .legacyWorkout:
            return nil
        }
    }

    var scheduleStartDate: Date? {
        get {
            switch self {
            case .custom(let preset):
                return preset.scheduleStartDate
            case .preMeal, .legacyWorkout:
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
            case .preMeal, .legacyWorkout:
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
            case .legacyWorkout: return "Workout"
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
            case .legacyWorkout(let range, _): return range
            }
        }

        set {
            switch self {
            case .preMeal:
                self = .preMeal(range: newValue!)
            case .legacyWorkout(_, let duration):
                self = .legacyWorkout(range: newValue!, duration: duration)
            case .custom(var preset):
                preset.settings = TemporaryPresetSettings(targetRange: newValue, insulinNeedsScaleFactor: preset.settings.insulinNeedsScaleFactor)
                self = .custom(preset)
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
    
    var insulinNeedsScaleFactor: Double {
        get {
            if case .custom(let preset) = self {
                return 1.0 / (preset.settings.insulinSensitivityMultiplier ?? 1)
            } else {
                return 1.0
            }
        }
        set {
            if case .custom(var preset) = self {
                preset.settings = TemporaryPresetSettings(targetRange: preset.settings.targetRange, insulinNeedsScaleFactor: newValue)
                self = .custom(preset)
            }
        }
    }

    var canAdjustSensitivity: Bool {
        switch self {
        case .custom:
            return true
        case .preMeal, .legacyWorkout:
            return false
        }
    }

    var canAdjustDuration: Bool {
        switch self {
        case .custom, .legacyWorkout:
            return true;
        case .preMeal:
            return false;
        }
    }

    var canChangeName: Bool {
        switch self {
        case .custom:
            return true;
        case .preMeal, .legacyWorkout:
            return false;
        }
    }

    var allowsScheduling: Bool {
        switch self {
        case .custom:
            return true;
        case .preMeal, .legacyWorkout:
            return false;
        }
    }

    var canBeDeleted: Bool {
        switch self {
        case .custom:
            return true;
        case .preMeal, .legacyWorkout:
            return false;
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
