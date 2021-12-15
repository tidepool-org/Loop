//
//  NotificationsCriticalAlertPermissionsViewModel.swift
//  LoopUI
//
//  Created by Rick Pasetto on 6/5/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import Foundation
import LoopKit
import SwiftUI
import TidepoolOnboarding

public class NotificationsCriticalAlertPermissionsViewModel: ObservableObject {
    
    public enum Warning {
        case notificationPermissions, timeSensitive, scheduledDelivery, criticalAlerts
    }

    @Published var notificationsPermissionsGiven: Bool
    @Published var timeSensitiveAlertsPermissionGiven: Bool
    @Published var scheduledDeliveryEnabled: Bool
    @Published var criticalAlertsPermissionsGiven: Bool

    // This is a "bridge" between old & new UI; it allows us to "combine" the two @Published variables above into
    // one published item, and also provides it in a way that may be `.assign`ed in the new UI (see `init()`) and
    // added as a `.sink` (see `SettingsTableViewController.swift`) in the old UI.
    lazy public var showWarningPublisher: AnyPublisher<Warning?, Never> = {
        Publishers.CombineLatest4($notificationsPermissionsGiven, $timeSensitiveAlertsPermissionGiven, $scheduledDeliveryEnabled, $criticalAlertsPermissionsGiven)
            .map { (notificationsPermissionsGiven: Bool, timeSensitiveAlertsPermissionGiven: Bool, scheduledDeliveryEnabled: Bool, criticalAlertsPermissionsGiven: Bool) -> Warning? in
                if !criticalAlertsPermissionsGiven && FeatureFlags.criticalAlertsEnabled {
                    return .criticalAlerts
                }
                if !timeSensitiveAlertsPermissionGiven {
                    return .timeSensitive
                }
                if scheduledDeliveryEnabled {
                    return .scheduledDelivery
                }
                if !notificationsPermissionsGiven {
                    return .notificationPermissions
                }
                return nil
            }
            .eraseToAnyPublisher()
    }()

    @Published var showWarning: Warning?
    lazy private var cancellables = Set<AnyCancellable>()
    
    public init(notificationsPermissionsGiven: Bool = true,
                timeSensitiveAlertsPermissionGiven: Bool = true,
                scheduledDeliveryEnabled: Bool = false,
                criticalAlertsPermissionsGiven: Bool = true) {
        self.notificationsPermissionsGiven = notificationsPermissionsGiven
        self.timeSensitiveAlertsPermissionGiven = timeSensitiveAlertsPermissionGiven
        self.scheduledDeliveryEnabled = scheduledDeliveryEnabled
        self.criticalAlertsPermissionsGiven = criticalAlertsPermissionsGiven

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.updateState()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.updateState()
            }
            .store(in: &cancellables)
        
        updateState()
        
        showWarningPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.showWarning, on: self)
            .store(in: &cancellables)
    }
    
    func updateState() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsPermissionsGiven = settings.alertSetting == .enabled
                self.criticalAlertsPermissionsGiven = settings.criticalAlertSetting == .enabled
                if #available(iOS 15.0, *) {
                    self.scheduledDeliveryEnabled = settings.scheduledDeliverySetting == .enabled
                    self.timeSensitiveAlertsPermissionGiven = settings.alertSetting == .disabled || settings.timeSensitiveSetting == .enabled
                }
            }
        }
    }
    
    public func gotoSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}
