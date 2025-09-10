//
//  LoopSettingsUserInfo.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopCore
import LoopKit

struct LoopSettingsUserInfo: Equatable {
    var loopSettings: LoopSettings
    var scheduleOverride: TemporaryScheduleOverride?
}

extension LoopSettingsUserInfo: RawRepresentable {
    typealias RawValue = [String: Any]

    static let name = "LoopSettingsUserInfo"
    static let version = 1

    init?(rawValue: RawValue) {
        guard rawValue["v"] as? Int == LoopSettingsUserInfo.version,
            rawValue["name"] as? String == LoopSettingsUserInfo.name,
            let settingsRaw = rawValue["s"] as? LoopSettings.RawValue,
            let loopSettings = LoopSettings(rawValue: settingsRaw)
        else {
            return nil
        }

        self.loopSettings = loopSettings

        if let rawScheduleOverride = rawValue["o"] as? TemporaryScheduleOverride.RawValue {
            self.scheduleOverride = TemporaryScheduleOverride(rawValue: rawScheduleOverride)
        } else {
            self.scheduleOverride = nil
        }
    }

    var rawValue: RawValue {
        var raw: RawValue = [
            "v": LoopSettingsUserInfo.version,
            "name": LoopSettingsUserInfo.name,
            "s": loopSettings.rawValue
        ]
        raw["o"] = scheduleOverride?.rawValue

        return raw
    }
}
