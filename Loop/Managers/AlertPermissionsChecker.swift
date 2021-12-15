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
    
    // MARK: Notifications Permissions Alert
    private static let notificationsPermissionsAlertIdentifier = Alert.Identifier(managerIdentifier: "LoopAppManager",
                                                                                  alertIdentifier: "notificationsPermissionsAlert")
    private static let notificationsPermissionsAlertContent = Alert.Content(
        title: NSLocalizedString("Notifications Disabled",
                                 comment: "Notifications permissions disabled alert title"),
        body: String(format: NSLocalizedString("Keep Notifications turned ON in your phone’s settings to ensure that you can receive %1$@ notifications.",
                                               comment: "Format for Notifications permissions disabled alert body. (1: app name)"),
                     Bundle.main.bundleDisplayName),
        acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "Notifications permissions disabled alert button")
    )
    private static let notificationsPermissionsAlert = Alert(identifier: notificationsPermissionsAlertIdentifier,
                                                             foregroundContent: notificationsPermissionsAlertContent,
                                                             backgroundContent: notificationsPermissionsAlertContent,
                                                             trigger: .immediate)
    
    // MARK: Critical Alert Permissions Alert
    private static let criticalAlertPermissionsAlertIdentifier = Alert.Identifier(managerIdentifier: "LoopAppManager",
                                                                                  alertIdentifier: "criticalAlertPermissionsAlert")
    private static let criticalAlertPermissionsAlertContent = Alert.Content(
        title: NSLocalizedString("Critical Alerts Disabled",
                                 comment: "Critical Alert permissions disabled alert title"),
        body: String(format: NSLocalizedString("Keep Critical Alerts turned ON in your phone’s settings to ensure that you can receive %1$@ critical alerts.",
                                               comment: "Format for Critical Alerts permissions disabled alert body. (1: app name)"),
                     Bundle.main.bundleDisplayName),
        acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "Critical Alert permissions disabled alert button")
    )
    private static let criticalAlertPermissionsAlert = Alert(identifier: criticalAlertPermissionsAlertIdentifier,
                                                             foregroundContent: criticalAlertPermissionsAlertContent,
                                                             backgroundContent: criticalAlertPermissionsAlertContent,
                                                             trigger: .immediate)

    // MARK: Time Sensitive Permissions Alert
    private static let timeSensitiveAlertsPermissionsAlertIdentifier = Alert.Identifier(managerIdentifier: "LoopAppManager",
                                                                                        alertIdentifier: "timeSensitiveAlertsPermissionsAlert")
    private static let timeSensitiveAlertsPermissionsAlertContent = Alert.Content(
        title: NSLocalizedString("Alert Permissions Need Attention",
                                 comment: "Alert Permissions Need Attention alert title"),
        body: String(format: NSLocalizedString("""
            Time Sensitive Notifications are turned off in your phone’s settings.
            
            Keep Time Sensitive Notifications turned ON to ensure that you can receive %1$@ notifications.
            """,
                                               comment: "Format for Time Sensitive Notifications permissions disabled alert body. (1: app name)"),
                     Bundle.main.bundleDisplayName),
        acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "Time Sensitive Notifications permissions disabled alert button")
    )
    private static let timeSensitiveAlertsPermissionsAlert = Alert(identifier: timeSensitiveAlertsPermissionsAlertIdentifier,
                                                             foregroundContent: timeSensitiveAlertsPermissionsAlertContent,
                                                             backgroundContent: timeSensitiveAlertsPermissionsAlertContent,
                                                             trigger: .immediate)

    // MARK: Scheduled Delivery Enabled Alert
    private static let scheduledDeliveryEnabledAlertIdentifier = Alert.Identifier(managerIdentifier: "LoopAppManager",
                                                                                  alertIdentifier: "scheduledDeliveryEnabledAlert")
    private static let scheduledDeliveryEnabledAlertContent = Alert.Content(
        title: NSLocalizedString("Alert Permissions Need Attention",
                                 comment: "Critical Alert permissions disabled alert title"),
        body: String(format: NSLocalizedString("Keep Critical Alerts turned ON in your phone’s settings to ensure that you can receive %1$@ critical alerts.",
                                               comment: "Format for Critical Alerts permissions disabled alert body. (1: app name)"),
                     Bundle.main.bundleDisplayName),
        acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "Critical Alert permissions disabled alert button")
    )
    private static let scheduledDeliveryEnabledAlert = Alert(identifier: scheduledDeliveryEnabledAlertIdentifier,
                                                             foregroundContent: scheduledDeliveryEnabledAlertContent,
                                                             backgroundContent: scheduledDeliveryEnabledAlertContent,
                                                             trigger: .immediate)

    private weak var alertManager: AlertManager?
    
    private var isAppInBackground: Bool {
        return UIApplication.shared.applicationState == UIApplication.State.background
    }
    
    private lazy var cancellables = Set<AnyCancellable>()

    let viewModel = NotificationsCriticalAlertPermissionsViewModel()
    
    init(alertManager: AlertManager) {
        self.alertManager = alertManager
        
        // Check on loop complete, but only while in the background.
        NotificationCenter.default.publisher(for: .LoopCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isAppInBackground {
                    self.viewModel.updateState()
                }
            }
            .store(in: &cancellables)
                
        if FeatureFlags.criticalAlertsEnabled {
            viewModel.$criticalAlertsPermissionsGiven
                .receive(on: RunLoop.main)
                .sink {
                    if $0 {
                        self.criticalAlertPermissionsEnabled()
                    } else {
                        self.maybeNotifyCriticalAlertPermissionsDisabled()
                    }
                }
                .store(in: &cancellables)
        }
        viewModel.$notificationsPermissionsGiven
            .receive(on: RunLoop.main)
            .sink {
                if $0 {
                    self.notificationsPermissionsEnabled()
                } else {
                    self.maybeNotifyNotificationPermissionsDisabled()
                }
            }
            .store(in: &cancellables)
        viewModel.$timeSensitiveAlertsPermissionGiven
            .receive(on: RunLoop.main)
            .sink {
                if $0 {
                    self.timeSensitiveAlertsPermissionEnabled()
                } else {
                    self.maybeNotifyTimeSensitiveAlertsPermissionsDisabled()
                }
            }
            .store(in: &cancellables)
        viewModel.$scheduledDeliveryEnabled
            .receive(on: RunLoop.main)
            .sink {
                if $0 {
                    self.maybeNotifyScheduledDeliveryEnabled()
                } else {
                    self.scheduledDeliveryDisabled()
                }
            }
            .store(in: &cancellables)
    }
    
    private func maybeNotifyNotificationPermissionsDisabled() {
        if !UserDefaults.standard.hasIssuedNotificationsPermissionsAlert {
            alertManager?.issueAlert(AlertPermissionsChecker.notificationsPermissionsAlert)
            UserDefaults.standard.hasIssuedNotificationsPermissionsAlert = true
        }
    }

    private func notificationsPermissionsEnabled() {
        alertManager?.retractAlert(identifier: AlertPermissionsChecker.notificationsPermissionsAlertIdentifier)
        UserDefaults.standard.hasIssuedNotificationsPermissionsAlert = false
    }

    private func maybeNotifyCriticalAlertPermissionsDisabled() {
        if !UserDefaults.standard.hasIssuedCriticalAlertPermissionsAlert {
            alertManager?.issueAlert(AlertPermissionsChecker.criticalAlertPermissionsAlert)
            UserDefaults.standard.hasIssuedCriticalAlertPermissionsAlert = true
        }
    }

    private func criticalAlertPermissionsEnabled() {
        alertManager?.retractAlert(identifier: AlertPermissionsChecker.criticalAlertPermissionsAlertIdentifier)
        UserDefaults.standard.hasIssuedCriticalAlertPermissionsAlert = false
    }

    private func maybeNotifyTimeSensitiveAlertsPermissionsDisabled() {
        if !UserDefaults.standard.hasIssuedTimeSensitiveAlertsPermissionsAlert {
            alertManager?.issueAlert(AlertPermissionsChecker.timeSensitiveAlertsPermissionsAlert)
            UserDefaults.standard.hasIssuedTimeSensitiveAlertsPermissionsAlert = true
        }
    }

    private func timeSensitiveAlertsPermissionEnabled() {
        alertManager?.retractAlert(identifier: AlertPermissionsChecker.timeSensitiveAlertsPermissionsAlertIdentifier)
        UserDefaults.standard.hasIssuedTimeSensitiveAlertsPermissionsAlert = false
    }

    private func maybeNotifyScheduledDeliveryEnabled() {
        if !UserDefaults.standard.hasIssuedScheduledDeliveryEnabledAlert {
            alertManager?.issueAlert(AlertPermissionsChecker.scheduledDeliveryEnabledAlert)
            UserDefaults.standard.hasIssuedScheduledDeliveryEnabledAlert = true
        }
    }

    private func scheduledDeliveryDisabled() {
        alertManager?.retractAlert(identifier: AlertPermissionsChecker.scheduledDeliveryEnabledAlertIdentifier)
        UserDefaults.standard.hasIssuedScheduledDeliveryEnabledAlert = false
    }
    
    func alert(for warning: NotificationsCriticalAlertPermissionsViewModel.Warning) -> LoopKit.Alert {
        switch warning {
        case .notificationPermissions:
            return Self.notificationsPermissionsAlert
        case .timeSensitive:
            return Self.timeSensitiveAlertsPermissionsAlert
        case .scheduledDelivery:
            return Self.scheduledDeliveryEnabledAlert
        case .criticalAlerts:
            return Self.criticalAlertPermissionsAlert
        }
    }
}

extension UserDefaults {
    
    private enum Key: String {
        case hasIssuedNotificationsPermissionsAlert = "com.loopkit.Loop.HasIssuedNotificationsPermissionsAlert"
        case hasIssuedCriticalAlertPermissionsAlert = "com.loopkit.Loop.HasIssuedCriticalAlertPermissionsAlert"
        case hasIssuedTimeSensitiveAlertsPermissionsAlert = "com.loopkit.Loop.HasIssuedTimeSensitiveAlertsPermissionsAlert"
        case hasIssuedScheduledDeliveryEnabledAlert = "com.loopkit.Loop.HasIssuedScheduledDeliveryEnabledAlert"
    }
    
    var hasIssuedNotificationsPermissionsAlert: Bool {
        get {
            return object(forKey: Key.hasIssuedNotificationsPermissionsAlert.rawValue) as? Bool ?? false
        }
        set {
            set(newValue, forKey: Key.hasIssuedNotificationsPermissionsAlert.rawValue)
        }
    }
    
    var hasIssuedCriticalAlertPermissionsAlert: Bool {
        get {
            return object(forKey: Key.hasIssuedCriticalAlertPermissionsAlert.rawValue) as? Bool ?? false
        }
        set {
            set(newValue, forKey: Key.hasIssuedCriticalAlertPermissionsAlert.rawValue)
        }
    }

    var hasIssuedTimeSensitiveAlertsPermissionsAlert: Bool {
        get {
            return object(forKey: Key.hasIssuedTimeSensitiveAlertsPermissionsAlert.rawValue) as? Bool ?? false
        }
        set {
            set(newValue, forKey: Key.hasIssuedTimeSensitiveAlertsPermissionsAlert.rawValue)
        }
    }

    var hasIssuedScheduledDeliveryEnabledAlert: Bool {
        get {
            return object(forKey: Key.hasIssuedScheduledDeliveryEnabledAlert.rawValue) as? Bool ?? false
        }
        set {
            set(newValue, forKey: Key.hasIssuedScheduledDeliveryEnabledAlert.rawValue)
        }
    }
}
