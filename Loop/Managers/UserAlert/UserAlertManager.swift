//
//  UserAlertManager.swift
//  Loop
//
//  Created by Rick Pasetto on 4/9/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

/// Main (singleton-ish) class that is responsible for:
/// - managing the different targets (handlers) that will post alerts
/// - serializing alerts to storage
/// - etc.
public final class UserAlertManager {

    let handlers: [DeviceAlertHandler]
    
    public init(rootViewController: UIViewController, isAppInBackgroundFunc: @escaping () -> Bool) {
        handlers = [UserNotificationAlertHandler(isAppInBackgroundFunc: isAppInBackgroundFunc),
                    InAppUserAlertHandler(rootViewController: rootViewController)]
    }
}

extension UserAlertManager: DeviceAlertHandler {

    public func issueAlert(_ alert: DeviceAlert) {
        handlers.forEach { $0.issueAlert(alert) }
    }
    public func removePendingAlerts(identifier: DeviceAlert.Identifier) {
        handlers.forEach { $0.removePendingAlerts(identifier: identifier) }
    }
    public func removeDeliveredAlerts(identifier: DeviceAlert.Identifier) {
        handlers.forEach { $0.removeDeliveredAlerts(identifier: identifier) }
    }
}
