//
//  NotificationActionSelection.swift
//  Loop
//
//  Created by Pete Schwamb on 7/16/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


struct NotificationActionSelection {
    let version = 1
    let alertIdentifier: String
    let managerIdentifier: String
    let actionIdentifier: String
}

extension NotificationActionSelection: RawRepresentable {
    typealias RawValue = [String: Any]

    static let name = "NotificationActionSelection"

    init?(rawValue: RawValue) {
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

    var rawValue: RawValue {
        return [
            "v": version,
            "name": NotificationActionSelection.name,
            "alertIdentifier": alertIdentifier,
            "managerIdentifier": managerIdentifier,
            "actionIdentifier": actionIdentifier,
        ]
    }
}
