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
    static let monday = PresetScheduleRepeatOptions(rawValue: 1 << 0)
    static let tuesday = PresetScheduleRepeatOptions(rawValue: 1 << 1)
    static let wednesday = PresetScheduleRepeatOptions(rawValue: 1 << 2)
    static let thursday = PresetScheduleRepeatOptions(rawValue: 1 << 3)
    static let friday = PresetScheduleRepeatOptions(rawValue: 1 << 4)
    static let saturday = PresetScheduleRepeatOptions(rawValue: 1 << 5)
    static let sunday = PresetScheduleRepeatOptions(rawValue: 1 << 6)

    static let allCases: [PresetScheduleRepeatOptions] = [
        .sunday,
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
    ]
}

extension PresetScheduleRepeatOptions: CustomStringConvertible {

    var description: String {
        switch self {
        case .monday:
            return NSLocalizedString("Monday", comment: "Preset schedule repeat option monday")
        case .tuesday:
            return NSLocalizedString("Tuesday", comment: "Preset schedule repeat option tuesday")
        case .wednesday:
            return NSLocalizedString("Wednesday", comment: "Preset schedule repeat option wednesday")
        case .thursday:
            return NSLocalizedString("Thursday", comment: "Preset schedule repeat option thursday")
        case .friday:
            return NSLocalizedString("Friday", comment: "Preset schedule repeat option friday")
        case .saturday:
            return NSLocalizedString("Saturday", comment: "Preset schedule repeat option saturday")
        case .sunday:
            return NSLocalizedString("Sunday", comment: "Preset schedule repeat option sunday")
        case .none:
            return NSLocalizedString("None", comment: "Preset schedule repeat option none")
        default:
            return NSLocalizedString("Multiple", comment: "Preset schedule repeat option multiple days")
        }
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
    var enactablePreset: TemporaryScheduleOverridePreset? {

        let overrideDuration: TemporaryScheduleOverride.Duration
        switch duration {
        case .duration(let interval):
            overrideDuration = .finite(interval)
        default:
            overrideDuration = .indefinite
        }
        return TemporaryScheduleOverridePreset(
            symbol: "",
            name: name,
            settings: TemporaryScheduleOverrideSettings(
                targetRange: correctionRange,
                insulinNeedsScaleFactor: insulinMultiplier
            ),
            duration: overrideDuration
        )
    }
}
