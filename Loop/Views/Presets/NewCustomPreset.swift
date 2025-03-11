//
//  NewCustomPreset.swift
//  Loop
//
//  Created by Pete Schwamb on 2/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import UIKit

enum PresetScheduleRepeatOption: CaseIterable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
}

extension PresetScheduleRepeatOption: CustomStringConvertible {
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
        }
    }
}

struct NewCustomPreset {
    var savePreset: Bool = true
    var insulinMultiplier: Double = 1
    var correctionRange: ClosedRange<LoopQuantity>?
    var name: String = ""
    var duration: PresetDuration?
    var scheduledDate: Date?
    var repeatOptions: PresetScheduleRepeatOption?
}
