//
//  UserNotificationDeviceAlertPresenter.swift
//  LoopKit
//
//  Created by Rick Pasetto on 4/9/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import UserNotifications

protocol UserNotificationCenter {
    func add(_ request: UNNotificationRequest, withCompletionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers: [String])
    func removeDeliveredNotifications(withIdentifiers: [String])
}

extension UNUserNotificationCenter: UserNotificationCenter {}

class UserNotificationDeviceAlertPresenter: DeviceAlertPresenter {
    
    let userNotificationCenter: UserNotificationCenter
    let log = DiagnosticLog(category: "UserNotificationDeviceAlertPresenter")
    
    init(userNotificationCenter: UserNotificationCenter = UNUserNotificationCenter.current()) {
        self.userNotificationCenter = userNotificationCenter
    }
        
    func issueAlert(_ alert: DeviceAlert) {
        DispatchQueue.main.async {
            do {
                let request = try alert.asUserNotificationRequest()
                self.userNotificationCenter.add(request) { error in
                    if let error = error {
                        self.log.error("Something went wrong posting the user notification: %@", error.localizedDescription)
                    }
                }
                // For now, UserNotifications do not not acknowledge...not yet at least
            } catch {
                self.log.error("Error issuing alert: %@", error.localizedDescription)
            }
        }
    }
    
    func removePendingAlert(identifier: DeviceAlert.Identifier) {
        DispatchQueue.main.async {
            self.userNotificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier.value])
        }
    }
    
    func removeDeliveredAlert(identifier: DeviceAlert.Identifier) {
        DispatchQueue.main.async {
            self.userNotificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier.value])
        }
    }
}
