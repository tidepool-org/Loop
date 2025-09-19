//
//  SetPresetUserInfo.swift
//  Loop
//
//  Created by Pete Schwamb on 9/18/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

public struct SetPresetUserInfo {
    let version = 1
    public let presetIdentifier: String? // nil = clear preset
    public let alertIdentifier: String? // alertIdentifier to acknowledge, if any

    public init(presetIdentifier: String?, alertIdentifier: String? = nil) {
        self.presetIdentifier = presetIdentifier
        self.alertIdentifier = alertIdentifier
    }
}

extension SetPresetUserInfo: RawRepresentable {
    public typealias RawValue = [String: Any]

    public static let name = "SetPresetUserInfo"

    public init?(rawValue: RawValue) {
        guard
            rawValue["v"] as? Int == version,
            rawValue["name"] as? String == SetPresetUserInfo.name
            else {
                return nil
        }

        self.presetIdentifier = rawValue["pi"] as? String
        self.alertIdentifier = rawValue["aa"] as? String
    }

    public var rawValue: RawValue {
        var rVal: RawValue = [
            "v": version,
            "name": SetPresetUserInfo.name
        ]

        rVal["pi"] = presetIdentifier
        rVal["aa"] = alertIdentifier

        return rVal
    }
}
