//
//  InAppUserAlertHandler.swift
//  LoopKit
//
//  Created by Rick Pasetto on 4/9/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

public class InAppModalDeviceAlertHandler: DeviceAlertHandler {
    
    private weak var rootViewController: UIViewController?
    private weak var deviceAlertManagerResponder: DeviceAlertManagerResponder?
    
    private var alertsShowing: [(UIAlertController, DeviceAlert)] = []
    private var alertsPending: [(Timer, DeviceAlert)] = []
    
    init(rootViewController: UIViewController, deviceAlertManagerResponder: DeviceAlertManagerResponder) {
        self.rootViewController = rootViewController
        self.deviceAlertManagerResponder = deviceAlertManagerResponder
    }
        
    public func issueAlert(_ alert: DeviceAlert) {
        switch alert.trigger {
        case .immediate:
            show(alert: alert)
        case .delayed(let interval):
            schedule(alert: alert, interval: interval, repeats: false)
        case .repeating(let interval):
            schedule(alert: alert, interval: interval, repeats: true)
        }
    }
    
    public func removePendingAlerts(identifier: DeviceAlert.Identifier) {
        DispatchQueue.main.async {
            self.alertsPending.filter {
                $0.1.identifier == identifier
            }
            .forEach { timer, alert in
                timer.invalidate()
            }
            self.alertsPending.removeAll { $0.1.identifier == identifier }
        }
    }
    
    public func removeDeliveredAlerts(identifier: DeviceAlert.Identifier) {
        DispatchQueue.main.async {
            self.alertsShowing.filter {
                $0.1.identifier == identifier
            }
            .forEach { alertController, alert in
                alertController.dismiss(animated: true)
            }
            self.alertsShowing.removeAll { $0.1.identifier == identifier }
        }
    }
}

/// Private functions
extension InAppModalDeviceAlertHandler {
    
    private func schedule(alert: DeviceAlert, interval: TimeInterval, repeats: Bool) {
        guard alert.foregroundContent != nil else {
            return
        }
        DispatchQueue.main.async {
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { [weak self] timer in
                self?.show(alert: alert)
                if !repeats {
                    self?.alertsPending.removeAll { $0.0 == timer && $0.1.identifier == alert.identifier }
                }
            }
            self.alertsPending.append((timer, alert))
        }
    }
    
    private func show(alert: DeviceAlert) {
        guard let content = alert.foregroundContent else {
            return
        }
        DispatchQueue.main.async {
            guard self.alertsShowing.contains(where: { $1.identifier == alert.identifier }) == false else {
                return
            }
            let alertController = self.presentAlert(title: content.title, message: content.body, action: content.acknowledgeActionButtonLabel) {
                self.alertsShowing.removeAll { $1.identifier == alert.identifier }
                self.deviceAlertManagerResponder?.acknowledgeDeviceAlert(deviceManagerInstanceIdentifier: alert.identifier.deviceManagerInstanceIdentifier,
                                                                         alertTypeIdentifier: alert.identifier.typeIdentifier)
            }
            self.alertsShowing.append((alertController, alert))
        }
    }
    
    private func presentAlert(title: String, message: String, action: String, completion: @escaping () -> Void) -> UIAlertController {
        // For now, this is a simple alert with an "OK" button
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: action, style: .default, handler: { _ in completion() }))
        topViewController(controller: rootViewController)?.present(alertController, animated: true)
        return alertController
    }
    
    // Helper function pulled from SO...may be outdated, especially in the SwiftUI world
    private func topViewController(controller: UIViewController?) -> UIViewController? {
        if let tabController = controller as? UITabBarController {
            return topViewController(controller: tabController.selectedViewController)
        }
        if let navController = controller as? UINavigationController {
            return topViewController(controller: navController.visibleViewController)
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
    
}
