//
//  RootNavigationController.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

/// The root view controller in Loop
class RootNavigationController: UINavigationController {
    override func restoreUserActivityState(_ activity: NSUserActivity) {
        switch activity.activityType {
        case NSUserActivity.viewLoopStatusActivityType:
            if presentedViewController != nil {
                dismiss(animated: false, completion: nil)
            }

            if viewControllers.count > 1 {
                popToRootViewController(animated: false)
            }
        default:
            viewControllers.first?.restoreUserActivityState(activity)
        }
    }
}
