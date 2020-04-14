//
//  DeviceAlertManager.swift
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
public final class DeviceAlertManager {

    let handlers: [DeviceAlertHandler]
    var responders: [String: Weak<DeviceAlertResponder>] = [:]
    
    public init(rootViewController: UIViewController,
                isAppInBackgroundFunc: @escaping () -> Bool) {
        handlers = [UserNotificationDeviceAlertHandler(isAppInBackgroundFunc: isAppInBackgroundFunc),
                    InAppModalDeviceAlertHandler(rootViewController: rootViewController)]
    }
    
    public func addAlertResponder(key: String, alertResponder: DeviceAlertResponder) {
        responders[key] = Weak(alertResponder)
    }
    
    public func acknowledgeDeviceAlert(managerIdentifier: String, alertTypeIdentifier: DeviceAlert.TypeIdentifier) {
        if let responder = responders[managerIdentifier]?.value {
            responder.acknowledgeAlert(typeIdentifier: alertTypeIdentifier)
        }
    }
}

extension DeviceAlertManager: DeviceAlertHandler {

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


