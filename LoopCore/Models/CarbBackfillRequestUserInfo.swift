//
//  CarbBackfillRequestUserInfo.swift
//  Loop
//
//  Created by Darin Krauss on 8/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public struct CarbBackfillRequestUserInfo {
    let version = 1
    public let startDate: Date

    public init(startDate: Date) {
        self.startDate = startDate
    }
}

extension CarbBackfillRequestUserInfo: RawRepresentable {
    public typealias RawValue = [String: Any]

    public static let name = "CarbBackfillRequestUserInfo"

    public init?(rawValue: RawValue) {
        guard
            rawValue["v"] as? Int == version,
            rawValue["name"] as? String == CarbBackfillRequestUserInfo.name,
            let startDate = rawValue["sd"] as? Date
            else {
                return nil
        }

        self.startDate = startDate
    }

    public var rawValue: RawValue {
        return [
            "v": version,
            "name": CarbBackfillRequestUserInfo.name,
            "sd": startDate
        ]
    }
}
