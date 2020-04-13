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
        if let trigger = alert.trigger {
            
            let timer = Timer(timeInterval: trigger.timeInterval, repeats: trigger.repeats) { [weak self] timer in
                self?.show(alert: alert)
                if !trigger.repeats {
                    self?.alertsPending.removeAll { $0.0 == timer && $0.1.identifier == alert.identifier }
                }
            }
            alertsPending.append((timer, alert))
        } else {
            show(alert: alert)
        }
    }
    
    public func unscheduleAlert(identifier: String) {
        // Cancel if already up
        cancelAlert(identifier: identifier)
        alertsPending.filter {
            $0.1.identifier == identifier
        }
        .forEach { timer, alert in
            timer.invalidate()
        }
    }
    
    public func cancelAlert(identifier: String) {
        alertsShowing.filter {
            $0.1.identifier == identifier
        }
        .forEach { alertController, alert in
            alertController.dismiss(animated: true)
        }
    }
}

/// Private functions
extension InAppUserAlertHandler {
    
    private func show(alert: UserAlert) {
        DispatchQueue.main.async {
            let content = alert.foregroundContent
            let alertController = self.presentAlert(title: content.title,message: content.body, action: content.dismissAction) {
                alert.acknowledgeCompletion?(alert)
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
