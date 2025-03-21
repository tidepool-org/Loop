//
//  NewCustomPreset.swift
//  Loop
//
//  Created by Pete Schwamb on 2/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import UIKit
import LoopKit

struct PresetScheduleRepeatOptions: OptionSet {
    let rawValue: UInt8

    static let none = PresetScheduleRepeatOptions([])
    static let sunday = PresetScheduleRepeatOptions(rawValue: 1 << 0)
    static let monday = PresetScheduleRepeatOptions(rawValue: 1 << 1)
    static let tuesday = PresetScheduleRepeatOptions(rawValue: 1 << 2)
    static let wednesday = PresetScheduleRepeatOptions(rawValue: 1 << 3)
    static let thursday = PresetScheduleRepeatOptions(rawValue: 1 << 4)
    static let friday = PresetScheduleRepeatOptions(rawValue: 1 << 5)
    static let saturday = PresetScheduleRepeatOptions(rawValue: 1 << 6)

    static let allCases: [PresetScheduleRepeatOptions] = [
        .sunday,
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
    ]

    // Helper to map OptionSet to calendar weekday index (Sunday = 1 in Calendar)
    private var calendarWeekdayIndex: Int? {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        default: return nil
        }
    }
}

extension PresetScheduleRepeatOptions: CustomStringConvertible {
    var description: String {
        let calendar = Calendar.current
        let weekdaySymbols = calendar.weekdaySymbols

        if self == .none {
            return NSLocalizedString("None", comment: "Preset schedule repeat option none")
        }

        // Handle single day case
        if let weekdayIndex = calendarWeekdayIndex {
            return weekdaySymbols[weekdayIndex - 1] // -1 because array is 0-based
        }

        // Handle multiple days
        return NSLocalizedString("Multiple", comment: "Preset schedule repeat option multiple days")
    }

    var veryShortDescription: String {
        let calendar = Calendar.current
        let weekdaySymbols = calendar.veryShortWeekdaySymbols

        if self == .none {
            return NSLocalizedString("None", comment: "Preset schedule repeat option none")
        }

        // Handle single day case
        if let weekdayIndex = calendarWeekdayIndex {
            return weekdaySymbols[weekdayIndex - 1] // -1 because array is 0-based
        }

        // Handle multiple days
        return NSLocalizedString("Multiple", comment: "Preset schedule repeat option multiple days")
    }
}

struct NewCustomPreset {
    var savePreset: Bool = true
    var insulinMultiplier: Double = 1
    var correctionRange: ClosedRange<LoopQuantity>?
    var name: String = ""
    var duration: PresetDuration?
    var startDate: Date?
    var repeatOptions: PresetScheduleRepeatOptions?
}

extension NewCustomPreset {
    func scheduleDescription() -> String {
        guard let startDate = startDate, let repeatOptions = repeatOptions else {
            return ""
        }

        // Handle case where no days are selected
        if repeatOptions.isEmpty || repeatOptions == .none {
            return ""
        }

        // Get date formatter for time (will use user's locale)
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short // Uses locale-appropriate short time format (e.g., "10:00 AM" or "10:00")
        let timeString = timeFormatter.string(from: startDate)

        // Get all selected days
        let selectedDays = PresetScheduleRepeatOptions.allCases
            .filter { repeatOptions.contains($0) }
            .map { $0.description } // Already localized via your existing description

        // Format the days string based on count
        let daysString: String
        switch selectedDays.count {
        case 1:
            daysString = selectedDays[0]
        case 2:
            daysString = String(
                format: NSLocalizedString("%@ and %@", comment: "Format for two days"),
                selectedDays[0],
                selectedDays[1]
            )
        default:
            let lastDay = selectedDays.last ?? ""
            let otherDays = selectedDays.dropLast().joined(separator: NSLocalizedString(", ", comment: "Separator for multiple days"))
            daysString = String(
                format: NSLocalizedString("%@, and %@", comment: "Format for three or more days"),
                otherDays,
                lastDay
            )
        }

        // Combine with localized format string
        return String(
            format: NSLocalizedString("Repeats weekly on %@ at %@", comment: "Weekly repeat schedule format"),
            daysString,
            timeString
        )
    }
}

extension NewCustomPreset {
    var temporaryScheduleOverride: TemporaryScheduleOverride? {
        guard let duration else {
            return nil
        }
        let overrideDuration = duration.presetDuration

        let settings = TemporaryScheduleOverrideSettings(
            targetRange: correctionRange,
            insulinNeedsScaleFactor: insulinMultiplier
        )

        let context: TemporaryScheduleOverride.Context

        if savePreset {
            let preset = TemporaryScheduleOverridePreset(
                symbol: "",
                name: name,
                settings: settings,
                duration: overrideDuration
            )
            context = .preset(preset)
        } else {
            context = .custom
        }
        return TemporaryScheduleOverride(
            context: context,
            settings: settings,
            startDate: startDate ?? Date(),
            duration: overrideDuration,
            enactTrigger: .local,
            syncIdentifier: UUID()
        )
    }
}
