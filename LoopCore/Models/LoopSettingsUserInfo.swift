//
//  LoopSettingsUserInfo.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit

public struct LoopSettingsUserInfo: Equatable {
    public var loopSettings: LoopSettings
    public var scheduleOverride: TemporaryScheduleOverride?

    public init(loopSettings: LoopSettings, scheduleOverride: TemporaryScheduleOverride? = nil) {
        self.loopSettings = loopSettings
        self.scheduleOverride = scheduleOverride
    }
}

extension LoopSettingsUserInfo: RawRepresentable {
    public typealias RawValue = [String: Any]

    public static let name = "LoopSettingsUserInfo"
    static let version = 1

    public init?(rawValue: RawValue) {
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

    public var rawValue: RawValue {
        var raw: RawValue = [
            "v": LoopSettingsUserInfo.version,
            "name": LoopSettingsUserInfo.name,
            "s": loopSettings.rawValue
        ]
        raw["o"] = scheduleOverride?.rawValue

        return raw
    }
}
