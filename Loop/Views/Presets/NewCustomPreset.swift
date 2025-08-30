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

extension PresetScheduleRepeatOptions: @retroactive CustomStringConvertible {
    public var description: String {
        let calendar = Calendar.current
        let weekdaySymbols = calendar.weekdaySymbols

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
        if repeatOptions.isEmpty {
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
    var temporaryPreset: TemporaryPreset? {
        guard let duration else {
            return nil
        }
        let overrideDuration = duration.presetDuration

        let settings = TemporaryPresetSettings(
            targetRange: correctionRange,
            insulinNeedsScaleFactor: insulinMultiplier
        )
        
        let split = name.splitSymbolAndTitle()
        var symbol: PresetSymbol? = nil
        if let emoji = split.emoji {
            symbol = .emoji(emoji)
        }

        return TemporaryPreset(
            symbol: symbol,
            name: split.name,
            settings: settings,
            duration: overrideDuration,
            scheduleStartDate: startDate
        )
    }
}

private extension String {
    func splitSymbolAndTitle() -> (emoji: String?, name: String) {
        let trimmed = trimmingCharacters(in: .whitespaces)
        if let first = trimmed.first, first.isEmoji {
            let name = String(dropFirst()).trimmingCharacters(in: .whitespaces)
            return (emoji: String(first), name: name)
        } else {
            return (emoji: nil, name: trimmed)
        }
    }
}
