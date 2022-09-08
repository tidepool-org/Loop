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

protocol AlertPermissionsCheckerDelegate: AnyObject {
    func alertPermissions(requiresRiskMitigation: Bool, scheduledDeliveryEnabled: Bool)
}

public class AlertPermissionsChecker: ObservableObject {

    private var isAppInBackground: Bool {
        return UIApplication.shared.applicationState == UIApplication.State.background
    }

    private lazy var cancellables = Set<AnyCancellable>()
    private var listeningToNotificationCenter = false

    @Published var notificationCenterSettings: NotificationCenterSettingsFlags = .none

    var showWarning: Bool {
        notificationCenterSettings.requiresRiskMitigation
    }

    weak var delegate: AlertPermissionsCheckerDelegate?

    init() {
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

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.check()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.check()
            }
            .store(in: &cancellables)
    }

    func checkNow() {
        check {
            // Note: we do this, instead of calling notificationCenterSettingsChanged directly, so that we only
            // get called when it _changes_.
            self.listenToNotificationCenter()
        }
    }

    private func check(then completion: (() -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                var newSettings = self.notificationCenterSettings
                newSettings.notificationsDisabled = settings.alertSetting == .disabled
                if FeatureFlags.criticalAlertsEnabled {
                    newSettings.criticalAlertsDisabled = settings.criticalAlertSetting == .disabled
                }
                if #available(iOS 15.0, *) {
                    newSettings.scheduledDeliveryEnabled = settings.scheduledDeliverySetting == .enabled
                    newSettings.timeSensitiveNotificationsDisabled = settings.alertSetting != .disabled && settings.timeSensitiveSetting == .disabled
                }
                self.notificationCenterSettings = newSettings
                completion?()
            }
        }
    }

    static func gotoSettings() {
        // TODO with iOS 16 this API changes to UIApplication.openNotificationSettingsURLString
        if #available(iOS 15.4, *) {
            UIApplication.shared.open(URL(string: UIApplicationOpenNotificationSettingsURLString)!)
        } else {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
    }
}

fileprivate extension AlertPermissionsChecker {
    private func listenToNotificationCenter() {
        if !listeningToNotificationCenter {
            $notificationCenterSettings
                .receive(on: RunLoop.main)
                .removeDuplicates()
                .sink(receiveValue: notificationCenterSettingsChanged)
                .store(in: &cancellables)
            listeningToNotificationCenter = true
        }
    }

    private func notificationCenterSettingsChanged(_ newValue: NotificationCenterSettingsFlags) {
        delegate?.alertPermissions(requiresRiskMitigation: newValue.requiresRiskMitigation, scheduledDeliveryEnabled: newValue.scheduledDeliveryEnabled)
    }
}

struct NotificationCenterSettingsFlags: OptionSet {
    let rawValue: Int

    static let none = NotificationCenterSettingsFlags([])
    static let notificationsDisabled = NotificationCenterSettingsFlags(rawValue: 1 << 0)
    static let criticalAlertsDisabled = NotificationCenterSettingsFlags(rawValue: 1 << 1)
    static let timeSensitiveNotificationsDisabled = NotificationCenterSettingsFlags(rawValue: 1 << 2)
    static let scheduledDeliveryEnabled = NotificationCenterSettingsFlags(rawValue: 1 << 3)

    static let requiresRiskMitigation: NotificationCenterSettingsFlags = [ .notificationsDisabled, .criticalAlertsDisabled, .timeSensitiveNotificationsDisabled ]
}

extension NotificationCenterSettingsFlags {
    var notificationsDisabled: Bool {
        get {
            contains(.notificationsDisabled)
        }
        set {
            update(.notificationsDisabled, newValue)
        }
    }
    var criticalAlertsDisabled: Bool {
        get {
            contains(.criticalAlertsDisabled)
        }
        set {
            update(.criticalAlertsDisabled, newValue)
        }
    }
    var timeSensitiveNotificationsDisabled: Bool {
        get {
            contains(.timeSensitiveNotificationsDisabled)
        }
        set {
            update(.timeSensitiveNotificationsDisabled, newValue)
        }
    }
    var scheduledDeliveryEnabled: Bool {
        get {
            contains(.scheduledDeliveryEnabled)
        }
        set {
            update(.scheduledDeliveryEnabled, newValue)
        }
    }
    var requiresRiskMitigation: Bool {
        !self.intersection(.requiresRiskMitigation).isEmpty
    }
}

fileprivate extension OptionSet {
    mutating func update(_ element: Self.Element, _ value: Bool) {
        if value {
            insert(element)
        } else {
            remove(element)
        }
    }
}

