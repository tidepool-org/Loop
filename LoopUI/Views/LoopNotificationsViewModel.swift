//
//  LoopNotificationsViewModel.swift
//  LoopUI
//
//  Created by Rick Pasetto on 6/5/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftUI

public class LoopNotificationsViewModel: ObservableObject {
    
    @Published var notificationsPermissionsGiven = true
    @Published var criticalAlertsPermissionsGiven = true

    // Sad panda.  What I really want to do is make this a computed property of the above, but I can't.
    @Published public var showWarning = false
    
    public init() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) {
            [weak self] _ in
            self?.updateState()
        }
        updateState()
    }
    
    private func updateState() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsPermissionsGiven = settings.alertSetting == .enabled
                self.criticalAlertsPermissionsGiven = settings.criticalAlertSetting == .enabled
                self.showWarning = self.notificationsPermissionsGiven == false || self.criticalAlertsPermissionsGiven == false
            }
        }
    }
    
    public func gotoSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}
