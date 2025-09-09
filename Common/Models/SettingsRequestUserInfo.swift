//
//  SettingsRequestUserInfo.swift
//  Loop
//
//  Created by Pete Schwamb on 9/9/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation

struct SettingsRequestUserInfo {
    let version = 1
}

extension SettingsRequestUserInfo: RawRepresentable {
    typealias RawValue = [String: Any]

    static let name = "SettingsRequestUserInfo"

    init?(rawValue: RawValue) {
        guard
            rawValue["v"] as? Int == version,
            rawValue["name"] as? String == SettingsRequestUserInfo.name
            else {
                return nil
        }
    }

    var rawValue: RawValue {
        return [
            "v": version,
            "name": SettingsRequestUserInfo.name,
        ]
    }
}
