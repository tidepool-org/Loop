//
//  NewCustomPreset.swift
//  Loop
//
//  Created by Pete Schwamb on 2/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import UIKit

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
