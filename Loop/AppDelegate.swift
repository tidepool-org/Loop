//
//  AppDelegate.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/15/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import UIKit
import LoopKit

final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The shared app manager. Owned by the app delegate so that application-level
    /// callbacks (remote notifications, protected data) can reach it, while the
    /// window-tied lifecycle is driven by `SceneDelegate`.
    let loopAppManager = LoopAppManager()

    /// Launch options captured at process launch, forwarded to `loopAppManager`
    /// when the scene connects (the window does not yet exist at launch time).
    private(set) var launchOptions: [UIApplication.LaunchOptionsKey: Any]?

    private let log = DiagnosticLog(category: "AppDelegate")

    // MARK: - UIApplicationDelegate - Initialization

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        log.default("%{public}@ with launchOptions: %{public}@", #function, String(describing: launchOptions))

        setenv("CFNETWORK_DIAGNOSTICS", "3", 1)

        // The window is created and owned by the scene, so initialization of the
        // app manager is deferred to `SceneDelegate.scene(_:willConnectTo:options:)`.
        // Stash the launch options so the scene can forward them.
        self.launchOptions = launchOptions

        return true
    }

    // MARK: - UIApplicationDelegate - Environment

    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        DispatchQueue.main.async {
            if self.loopAppManager.isLaunchPending {
                self.loopAppManager.launch()
            }
        }
    }

    // MARK: - UIApplicationDelegate - Remote Notification

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        log.default(#function)

        loopAppManager.remoteNotificationRegistrationDidFinish(.success(deviceToken))
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        log.error("%{public}@ with error: %{public}@", #function, String(describing: error))
        loopAppManager.remoteNotificationRegistrationDidFinish(.failure(error))
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        log.default(#function)

        completionHandler(loopAppManager.handleRemoteNotification(userInfo as? [String: AnyObject]) ? .noData : .failed)
    }

    // MARK: - UIApplicationDelegate - Interface

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return loopAppManager.supportedInterfaceOrientations
    }
}
