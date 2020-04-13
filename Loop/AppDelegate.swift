//
//  AppDelegate.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/15/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import UIKit
import Intents
import LoopCore
import LoopKit
import LoopKitUI
import UserNotifications

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    private lazy var log = DiagnosticLog(category: "AppDelegate")

    private lazy var pluginManager = PluginManager()

    private var deviceDataManager: DeviceDataManager!
    private var userAlertManager: UserAlertManager!
    
    var window: UIWindow?

    private var rootViewController: RootNavigationController! {
        return window?.rootViewController as? RootNavigationController
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        userAlertManager = UserAlertManager(rootViewController: rootViewController, isAppInBackgroundFunc: isInBackground)
        deviceDataManager = DeviceDataManager(pluginManager: pluginManager, alertHandler: userAlertManager)

        SharedLogging.instance = deviceDataManager.loggingServicesManager

        NotificationManager.authorize(delegate: self)
        
        log.info(#function)

        deviceDataManager.analyticsServicesManager.application(application, didFinishLaunchingWithOptions: launchOptions)

        rootViewController.rootViewController.deviceManager = deviceDataManager
        
        let notificationOption = launchOptions?[.remoteNotification]
        
        if let notification = notificationOption as? [String: AnyObject] {
            deviceDataManager.handleRemoteNotification(notification)
        }
                
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        deviceDataManager.updatePumpManagerBLEHeartbeatPreference()
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    // MARK: - Continuity

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        if #available(iOS 12.0, *) {
            if userActivity.activityType == NewCarbEntryIntent.className {
                log.default("Restoring %{public}@ intent", userActivity.activityType)
                rootViewController.restoreUserActivityState(.forNewCarbEntry())
                return true
            }
        }

        switch userActivity.activityType {
        case NSUserActivity.newCarbEntryActivityType,
             NSUserActivity.viewLoopStatusActivityType:
            log.default("Restoring %{public}@ activity", userActivity.activityType)
            restorationHandler([rootViewController])
            return true
        default:
            return false
        }
    }
    
    // MARK: - Remote notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        log.default("RemoteNotifications device token: %{public}@", token)
        deviceDataManager.loopManager.settings.deviceToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        log.error("Failed to register: %{public}@", String(describing: error))
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let notification = userInfo as? [String: AnyObject] else {
            completionHandler(.failed)
            return
        }
      
        deviceDataManager.handleRemoteNotification(notification)
        completionHandler(.noData)
    }

    private func isInBackground() -> Bool {
        return UIApplication.shared.applicationState == .background
    }
}


extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
   
        
        switch response.actionIdentifier {
        case NotificationManager.Action.retryBolus.rawValue:
            if  let units = response.notification.request.content.userInfo[LoopNotificationUserInfoKey.bolusAmount.rawValue] as? Double,
                let startDate = response.notification.request.content.userInfo[LoopNotificationUserInfoKey.bolusStartDate.rawValue] as? Date,
                startDate.timeIntervalSinceNow >= TimeInterval(minutes: -5)
            {
                deviceDataManager.analyticsServicesManager.didRetryBolus()

                deviceDataManager.enactBolus(units: units, at: startDate) { (_) in
                    completionHandler()
                }
                return
            }
        case NotificationManager.Action.acknowledgeAlert.rawValue:
            if let alertID = response.notification.request.content.userInfo[LoopNotificationUserInfoKey.alertID.rawValue] as? Int,
                let managerIdentifier = response.notification.request.content.userInfo[LoopNotificationUserInfoKey.managerIDForAlert.rawValue] as? String {
                deviceDataManager.acknowledgeDeviceAlert(managerIdentifier: managerIdentifier, alertID: alertID)
            }
        default:
            break
        }

        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .alert])
    }
    
}
