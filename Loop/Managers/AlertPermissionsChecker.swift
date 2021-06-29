//
//  AlertPermissionsChecker.swift
//  Loop
//
//  Created by Rick Pasetto on 6/25/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import Combine
import LoopKit
import SwiftUI

class AlertPermissionsChecker {
    private static let criticalAlertPermissionsAlertIdentifier = Alert.Identifier(managerIdentifier: "LoopAppManager",
                                                                                  alertIdentifier: "criticalAlertPermissionsAlert")
    private static let criticalAlertPermissionsAlertContent = Alert.Content(
        title: NSLocalizedString("Alert Permissions Disabled",
                                 comment: "Critical Alert or Notifications permissions disabled alert title"),
        body: String(format: NSLocalizedString("Keep Notifications and Critical Alerts turned ON in your phone’s settings to ensure that you can receive %1$@ notifications.",
                                               comment: "Format for critical Alert or Notifications permissions disabled alert body. (1: app name)"),
                     Bundle.main.bundleDisplayName),
        acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "Critical Alert or Notifications permissions disabled alert button")
    )
    private static let criticalAlertPermissionsAlert = Alert(identifier: criticalAlertPermissionsAlertIdentifier,
                                                             foregroundContent: criticalAlertPermissionsAlertContent,
                                                             backgroundContent: criticalAlertPermissionsAlertContent,
                                                             trigger: .immediate)
    
    private weak var alertManager: AlertManager?
    
    private var isAppInBackground: Bool {
        return UIApplication.shared.applicationState == UIApplication.State.background
    }
    
    private lazy var cancellables = Set<AnyCancellable>()

    init(alertManager: AlertManager) {
        self.alertManager = alertManager
        
        // Check on loop complete, but only while in the background.
        NotificationCenter.default.publisher(for: .LoopCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isAppInBackground {
                    self.check()
                }
            }
            .store(in: &cancellables)
        
        // Check on app resume
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.check()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.check()
            }
            .store(in: &cancellables)
    }

    func check() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let notificationsPermissions = settings.alertSetting
                let criticalAlertsPermissions = settings.criticalAlertSetting
                
                if notificationsPermissions == .disabled || criticalAlertsPermissions == .disabled {
                    self.maybeNotifyPermissionsDisabled()
                } else {
                    self.permissionsEnabled()
                }
            }
        }
    }
    
    private func maybeNotifyPermissionsDisabled() {
        if !UserDefaults.standard.hasUserBeenNotifiedOfPermissionsAlert {
            alertManager?.issueAlert(AlertPermissionsChecker.criticalAlertPermissionsAlert)
            UserDefaults.standard.hasUserBeenNotifiedOfPermissionsAlert = true
        }
    }
    
    private func permissionsEnabled() {
        alertManager?.retractAlert(identifier: AlertPermissionsChecker.criticalAlertPermissionsAlertIdentifier)
        UserDefaults.standard.hasUserBeenNotifiedOfPermissionsAlert = false
    }
    
}

extension UserDefaults {
    
    private enum Key: String {
        case hasUserBeenNotifiedOfPermissionsAlert = "com.loopkit.Loop.HasUserBeenNotifiedOfPermissionsAlert"
    }
    
    var hasUserBeenNotifiedOfPermissionsAlert: Bool {
        get {
            return object(forKey: Key.hasUserBeenNotifiedOfPermissionsAlert.rawValue) as? Bool ?? false
        }
        set {
            set(newValue, forKey: Key.hasUserBeenNotifiedOfPermissionsAlert.rawValue)
        }
    }
}
