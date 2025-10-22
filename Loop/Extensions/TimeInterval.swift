//
//  TimeInterval.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2025-10-23.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//
import Foundation

extension TimeInterval {
    /// Formats a time interval as a truncated "time ago" string (e.g., "1 hr", "2 mins")
    var truncatedTimeAgoString: String? {
        let calendar = Calendar.current
        let now = Date()
        let past = now.addingTimeInterval(-self)

        let components = calendar.dateComponents([.day, .hour, .minute], from: past, to: now)
        if let days = components.day, days > 0 {
            return String.localizedStringWithFormat(
                NSLocalizedString("%d day", tableName: "LocalizablePlural", bundle: .main, value: "%d day", comment: "Singular/plural day count"),
                days
            )
        } else if let hours = components.hour, hours > 0 {
            return String.localizedStringWithFormat(
                NSLocalizedString("%d hr", tableName: "LocalizablePlural", bundle: .main, value: "%d hr", comment: "Singular/plural hour count"),
                hours
            )
        } else if let minutes = components.minute {
            return String.localizedStringWithFormat(
                NSLocalizedString("%d min", tableName: "LocalizablePlural", bundle: .main, value: "%d min", comment: "Singular/plural minute count"),
                minutes
            )
        } else {
            return nil
        }
    }
}
