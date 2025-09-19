//
//  NotificationActionSelection.swift
//  Loop
//
//  Created by Pete Schwamb on 7/16/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


public struct NotificationActionSelection {
    let version = 1
    public let alertIdentifier: String
    public let managerIdentifier: String
    public let actionIdentifier: String

    public init(alertIdentifier: String, managerIdentifier: String, actionIdentifier: String) {
        self.alertIdentifier = alertIdentifier
        self.managerIdentifier = managerIdentifier
        self.actionIdentifier = actionIdentifier
    }
}

extension NotificationActionSelection: RawRepresentable {
    public typealias RawValue = [String: Any]

    public static let name = "NotificationActionSelection"

    public init?(rawValue: RawValue) {
        guard
            rawValue["v"] as? Int == version,
            rawValue["name"] as? String == NotificationActionSelection.name,
            let alertIdentifier = rawValue["alertIdentifier"] as? String,
            let managerIdentifier = rawValue["managerIdentifier"] as? String,
            let actionIdentifier = rawValue["actionIdentifier"] as? String
            else {
                return nil
        }

        self.alertIdentifier = alertIdentifier
        self.managerIdentifier = managerIdentifier
        self.actionIdentifier = actionIdentifier
    }

    public var rawValue: RawValue {
        return [
            "v": version,
            "name": NotificationActionSelection.name,
            "alertIdentifier": alertIdentifier,
            "managerIdentifier": managerIdentifier,
            "actionIdentifier": actionIdentifier,
        ]
    }
}
