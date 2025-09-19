//
//  SettingsRequestUserInfo.swift
//  Loop
//
//  Created by Pete Schwamb on 9/9/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation

public struct SettingsRequestUserInfo {
    let version = 1

    public init() {}
}

extension SettingsRequestUserInfo: RawRepresentable {
    public typealias RawValue = [String: Any]

    public static let name = "SettingsRequestUserInfo"

    public init?(rawValue: RawValue) {
        guard
            rawValue["v"] as? Int == version,
            rawValue["name"] as? String == SettingsRequestUserInfo.name
            else {
                return nil
        }
    }

    public var rawValue: RawValue {
        return [
            "v": version,
            "name": SettingsRequestUserInfo.name,
        ]
    }
}
