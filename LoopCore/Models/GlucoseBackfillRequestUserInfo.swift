//
//  GlucoseBackfillRequestUserInfo.swift
//  Loop
//
//  Created by Bharat Mediratta on 6/21/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation

public struct GlucoseBackfillRequestUserInfo {
    let version = 1
    public let startDate: Date

    public init(startDate: Date) {
        self.startDate = startDate
    }
}

extension GlucoseBackfillRequestUserInfo: RawRepresentable {
    public typealias RawValue = [String: Any]

    public static let name = "GlucoseBackfillRequestUserInfo"

    public init?(rawValue: RawValue) {
        guard
            rawValue["v"] as? Int == version,
            rawValue["name"] as? String == GlucoseBackfillRequestUserInfo.name,
            let startDate = rawValue["sd"] as? Date
        else {
            return nil
        }

        self.startDate = startDate
    }

    public var rawValue: RawValue {
        return [
            "v": version,
            "name": GlucoseBackfillRequestUserInfo.name,
            "sd": startDate
        ]
    }
}
