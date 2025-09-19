//
//  AcknowledgeAlertUserInfo.swift
//  Loop
//
//  Created by Pete Schwamb on 9/19/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

public struct AcknowledgeAlertUserInfo {
    let version = 1
    public let alertIdentifier: String
    public let managerIdentifier: String

    public init(alertIdentifier: String, managerIdentifier: String) {
        self.alertIdentifier = alertIdentifier
        self.managerIdentifier = managerIdentifier
    }
}

extension AcknowledgeAlertUserInfo: RawRepresentable {
    public typealias RawValue = [String: Any]

    public static let name = "AcknowledgeAlertUserInfo"

    public init?(rawValue: RawValue) {
        guard
            rawValue["v"] as? Int == version,
            let alertIdentifier = rawValue["ai"] as? String,
            let managerIdentifier = rawValue["mi"] as? String
            else {
                return nil
        }

        self.alertIdentifier = alertIdentifier
        self.managerIdentifier = managerIdentifier
    }

    public var rawValue: RawValue {
        return [
            "v": version,
            "name": AcknowledgeAlertUserInfo.name,
            "ai": alertIdentifier,
            "mi": managerIdentifier,
        ]
    }
}
