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
                self.userNotificationCenter.add(alert.asUserNotificationRequest())
                // For now, UserNotifications do not not acknowledge...not yet at least
            }
        }
    }
    
    func unscheduleAlert(identifier: String) {
        userNotificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAlert(identifier: String) {
        userNotificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

public extension UserAlert {
    
    fileprivate func asUserNotificationRequest() -> UNNotificationRequest {
        return UNNotificationRequest(identifier: identifier,
                                     content: getUserNotificationContent(),
                                     trigger: trigger?.asUserNotificationTrigger())
    }
    
    private func getUserNotificationContent() -> UNNotificationContent {
        let content = backgroundContent ?? foregroundContent
        let userNotificationContent = UNMutableNotificationContent()
        userNotificationContent.title = content.title
        userNotificationContent.body = content.body
        userNotificationContent.sound = content.isCritical ? .defaultCritical : .default
        userNotificationContent.categoryIdentifier = LoopNotificationCategory.alert.rawValue
        userNotificationContent.threadIdentifier = identifier // Used to match categoryIdentifier, but I /think/ we want multiple threads for multiple alert types, no?
        userNotificationContent.userInfo = [
            LoopNotificationUserInfoKey.managerIDForAlert.rawValue: managerIdentifier,
            LoopNotificationUserInfoKey.alertID.rawValue: alertTypeId
        ]
        return userNotificationContent
    }
}

public extension UserAlert.Trigger {
    func asUserNotificationTrigger() -> UNNotificationTrigger {
        return UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: repeats)
    }
}

