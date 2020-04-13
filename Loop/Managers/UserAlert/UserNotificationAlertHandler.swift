//
//  UserNotificationAlertHandler.swift
//  LoopKit
//
//  Created by Rick Pasetto on 4/9/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import UserNotifications

class UserNotificationAlertHandler: UserAlertHandler {
    
    let alertInBackgroundOnly: Bool
    let isAppInBackgroundFunc: () -> Bool
    let userNotificationCenter: UNUserNotificationCenter = UNUserNotificationCenter.current()
    
    init(alertInBackgroundOnly: Bool = true, isAppInBackgroundFunc: @escaping () -> Bool) {
        self.alertInBackgroundOnly = alertInBackgroundOnly
        self.isAppInBackgroundFunc = isAppInBackgroundFunc
    }
        
    func scheduleAlert(_ alert: UserAlert) {
        DispatchQueue.main.async {
            if self.alertInBackgroundOnly && self.isAppInBackgroundFunc() || !self.alertInBackgroundOnly {
                if let request = alert.asUserNotificationRequest() {
                    self.userNotificationCenter.add(request)
                    // For now, UserNotifications do not not acknowledge...not yet at least
                }
            }
        }
    }
    
    func unscheduleAlert(managerIdentifier: String, typeIdentifier: UserAlert.TypeIdentifier) {
        userNotificationCenter.removePendingNotificationRequests(withIdentifiers:
            [UserAlert.getIdentifier(managerIdentifier: managerIdentifier, typeIdentifier: typeIdentifier)])
    }
    
    func cancelAlert(managerIdentifier: String, typeIdentifier: UserAlert.TypeIdentifier) {
        userNotificationCenter.removeDeliveredNotifications(withIdentifiers:
            [UserAlert.getIdentifier(managerIdentifier: managerIdentifier, typeIdentifier: typeIdentifier)])
    }
}

public extension UserAlert {
    
    fileprivate func asUserNotificationRequest() -> UNNotificationRequest? {
        guard let uncontent = getUserNotificationContent() else {
            return nil
        }
        return UNNotificationRequest(identifier: identifier,
                                     content: uncontent,
                                     trigger: trigger.asUserNotificationTrigger())
    }
    
    private func getUserNotificationContent() -> UNNotificationContent? {
        guard let content = backgroundContent else {
            return nil
        }
        let userNotificationContent = UNMutableNotificationContent()
        userNotificationContent.title = content.title
        userNotificationContent.body = content.body
        userNotificationContent.sound = content.isCritical ? .defaultCritical : .default
        // TODO: Once we have a final design and approval for custom UserNotification buttons, we'll need to set categoryIdentifier
//        userNotificationContent.categoryIdentifier = LoopNotificationCategory.alert.rawValue
        userNotificationContent.threadIdentifier = identifier // Used to match categoryIdentifier, but I /think/ we want multiple threads for multiple alert types, no?
        userNotificationContent.userInfo = [
            LoopNotificationUserInfoKey.managerIDForAlert.rawValue: managerIdentifier,
            LoopNotificationUserInfoKey.alertID.rawValue: typeIdentifier
        ]
        return userNotificationContent
    }
}

public extension UserAlert.Trigger {
    func asUserNotificationTrigger() -> UNNotificationTrigger? {
        switch self {
        case .immediate:
            return nil
        case .delayed(let timeInterval):
            return UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        case .repeating(let repeatInterval):
            return UNTimeIntervalNotificationTrigger(timeInterval: repeatInterval, repeats: true)
        }
    }
}

