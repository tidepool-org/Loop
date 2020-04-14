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

    let handlers: [UserAlertHandler]
    
    public init(rootViewController: UIViewController, isAppInBackgroundFunc: @escaping () -> Bool) {
        handlers = [UserNotificationAlertHandler(isAppInBackgroundFunc: isAppInBackgroundFunc),
                    InAppUserAlertHandler(rootViewController: rootViewController)]
    }
}

extension UserAlertManager: UserAlertHandler {

    public func scheduleAlert(_ alert: UserAlert) {
        handlers.forEach { $0.scheduleAlert(alert) }
    }
    public func unscheduleAlert(identifier: UserAlert.Identifier) {
        handlers.forEach { $0.unscheduleAlert(identifier: identifier) }
    }
    public func cancelAlert(identifier: UserAlert.Identifier) {
        handlers.forEach { $0.cancelAlert(identifier: identifier) }
    }
}
