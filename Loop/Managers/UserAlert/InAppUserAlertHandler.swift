//
//  InAppUserAlertHandler.swift
//  LoopKit
//
//  Created by Rick Pasetto on 4/9/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

public class InAppUserAlertHandler: UserAlertHandler {
    
    private weak var rootViewController: UIViewController?
    
    private var alertsShowing: [(UIAlertController, UserAlert)] = []
    private var alertsPending: [(Timer, UserAlert)] = []
    
    public init(rootViewController: UIViewController) {
        self.rootViewController = rootViewController
    }
        
    public func scheduleAlert(_ alert: UserAlert) {
        switch alert.trigger {
        case .immediate:
            show(alert: alert)
        case .delayed(let interval):
            schedule(alert: alert, interval: interval, repeats: false)
        case .repeating(let interval):
            schedule(alert: alert, interval: interval, repeats: true)
        }
    }
    
    public func unscheduleAlert(managerIdentifier: String, typeIdentifier: UserAlert.TypeIdentifier) {
        DispatchQueue.main.async {
            self.alertsPending.filter {
                $0.1.identifier == UserAlert.getIdentifier(managerIdentifier: managerIdentifier, typeIdentifier: typeIdentifier)
            }
            .forEach { timer, alert in
                timer.invalidate()
            }
        }
    }
    
    public func cancelAlert(managerIdentifier: String, typeIdentifier: UserAlert.TypeIdentifier) {
        DispatchQueue.main.async {
            self.alertsShowing.filter {
                $0.1.identifier == UserAlert.getIdentifier(managerIdentifier: managerIdentifier, typeIdentifier: typeIdentifier)
            }
            .forEach { alertController, alert in
                alertController.dismiss(animated: true)
            }
        }
    }
}

/// Private functions
extension InAppUserAlertHandler {
    
    private func schedule(alert: UserAlert, interval: TimeInterval, repeats: Bool) {
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
    
    private func show(alert: UserAlert) {
        guard let content = alert.foregroundContent else {
            return
        }
        DispatchQueue.main.async {
            guard self.alertsShowing.contains(where: { $1.identifier == alert.identifier }) == false else {
                return
            }
            let alertController = self.presentAlert(title: content.title, message: content.body, action: content.acknowledgeAction) {
                alert.acknowledgeCompletion?(alert.typeIdentifier)
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
