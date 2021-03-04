//
//  LoopAppManager.swift
//  Loop
//
//  Created by Darin Krauss on 2/16/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI

public protocol ViewControllerProvider: AnyObject {
    var viewController: UIViewController? { get set }
}

class LoopAppManager: NSObject {
    private enum State: Int {
        case initialize
        case launchManagers
        case launchOnboarding
        case launchHomeScreen
        case launchComplete

        var next: State { State(rawValue: rawValue + 1) ?? .launchComplete }
    }

    private var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    private var window: UIWindow?

    private var pluginManager: PluginManager!
    private var bluetoothStateManager: BluetoothStateManager!
    private var alertManager: AlertManager!
    private var loopAlertsManager: LoopAlertsManager!
    private var trustedTimeChecker: TrustedTimeChecker!
    private var deviceDataManager: DeviceDataManager!
    private var onboardingManager: OnboardingManager!

    private var state: State = .initialize

    private let log = DiagnosticLog(category: "LoopAppManager")

    // MARK: - Initialization

    func initialize(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        dispatchPrecondition(condition: .onQueue(.main))
        precondition(state == .initialize)

        self.launchOptions = launchOptions

        registerBackgroundTasks()

        self.state = state.next
    }

    func launch(into window: UIWindow?) {
        dispatchPrecondition(condition: .onQueue(.main))
        precondition(!isLaunchComplete)
        precondition(state != .initialize)

        guard isProtectedDataAvailable() else {
            log.default("Protected data not available; deferring launch...")
            return
        }

        self.window = window
        
        window?.tintColor = .loopAccent
        OrientationLock.deviceOrientationController = self
        UNUserNotificationCenter.current().delegate = self

        resumeLaunch()
    }

    var isLaunchComplete: Bool { state == .launchComplete }

    private func resumeLaunch() {
        launchManagers()
        launchOnboarding()
        launchHomeScreen()
    }

    private func launchManagers() {
        dispatchPrecondition(condition: .onQueue(.main))

        guard state == .launchManagers else {
            return
        }

        self.pluginManager = PluginManager()
        self.bluetoothStateManager = BluetoothStateManager()
        self.alertManager = AlertManager(viewControllerProvider: self,
                                         expireAfter: Bundle.main.localCacheDuration)
        self.loopAlertsManager = LoopAlertsManager(alertManager: alertManager,
                                                   bluetoothProvider: bluetoothStateManager)
        self.trustedTimeChecker = TrustedTimeChecker(alertManager: alertManager)
        self.deviceDataManager = DeviceDataManager(pluginManager: pluginManager,
                                                   alertManager: alertManager,
                                                   bluetoothProvider: bluetoothStateManager,
                                                   viewControllerProvider: self)
        SharedLogging.instance = deviceDataManager.loggingServicesManager

        scheduleBackgroundTasks()

        self.onboardingManager = OnboardingManager(pluginManager: pluginManager,
                                                   bluetoothProvider: bluetoothStateManager,
                                                   deviceDataManager: deviceDataManager,
                                                   servicesManager: deviceDataManager.servicesManager,
                                                   loopDataManager: deviceDataManager.loopManager,
                                                   viewControllerProvider: self,
                                                   userDefaults: UserDefaults.appGroup!)

        deviceDataManager.analyticsServicesManager.application(didFinishLaunchingWithOptions: launchOptions)

        self.state = state.next
    }

    private func launchOnboarding() {
        dispatchPrecondition(condition: .onQueue(.main))

        guard state == .launchOnboarding else {
            return
        }

        onboardingManager.onboard {
            DispatchQueue.main.async {
                self.state = self.state.next
                self.resumeLaunch()
            }
        }
    }

    private func launchHomeScreen() {
        dispatchPrecondition(condition: .onQueue(.main))

        guard state == .launchHomeScreen else {
            return
        }

        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: Self.self))
        let statusTableViewController = storyboard.instantiateViewController(withIdentifier: "MainStatusViewController") as! StatusTableViewController
        statusTableViewController.deviceManager = deviceDataManager
        bluetoothStateManager.addBluetoothObserver(statusTableViewController)

        let rootNavigationController = RootNavigationController()
        viewController = rootNavigationController
        rootNavigationController.setViewControllers([statusTableViewController], animated: true)

        handleRemoteNotificationFromLaunchOptions()

        self.launchOptions = nil

        self.state = state.next
    }

    // MARK: - Life Cycle

    func didBecomeActive() {
        deviceDataManager?.updatePumpManagerBLEHeartbeatPreference()
    }

    // MARK: - Remote Notification

    func setRemoteNotificationsDeviceToken(_ remoteNotificationsDeviceToken: Data) {
        deviceDataManager?.loopManager.settings.deviceToken = remoteNotificationsDeviceToken
    }

    private func handleRemoteNotificationFromLaunchOptions() {
        handleRemoteNotification(launchOptions?[.remoteNotification] as? [String: AnyObject])
    }

    @discardableResult
    func handleRemoteNotification(_ notification: [String: AnyObject]?) -> Bool {
        guard let notification = notification else {
            return false
        }
        deviceDataManager?.handleRemoteNotification(notification)
        return true
    }

    // MARK: - Continuity

    func userActivity(_ userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if #available(iOS 12.0, *) {
            if userActivity.activityType == NewCarbEntryIntent.className {
                log.default("Restoring %{public}@ intent", userActivity.activityType)
                viewController?.restoreUserActivityState(.forNewCarbEntry())
                return true
            }
        }

        switch userActivity.activityType {
        case NSUserActivity.newCarbEntryActivityType,
             NSUserActivity.viewLoopStatusActivityType:
            log.default("Restoring %{public}@ activity", userActivity.activityType)
            if let viewController = viewController {
                restorationHandler([viewController])
            }
            return true
        default:
            return false
        }
    }

    // MARK: - Interface

    private static let defaultSupportedInterfaceOrientations = UIInterfaceOrientationMask.allButUpsideDown

    var supportedInterfaceOrientations = defaultSupportedInterfaceOrientations

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        if DeviceDataManager.registerCriticalEventLogHistoricalExportBackgroundTask({ self.deviceDataManager?.handleCriticalEventLogHistoricalExportBackgroundTask($0) }) {
            log.debug("Critical event log export background task registered")
        } else {
            log.error("Critical event log export background task not registered")
        }
    }

    private func scheduleBackgroundTasks() {
        deviceDataManager?.scheduleCriticalEventLogHistoricalExportBackgroundTask()
    }

    // MARK: - Private

    private func isProtectedDataAvailable() -> Bool {
        let fileManager = FileManager.default
        do {
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let fileURL = documentDirectory.appendingPathComponent("protection.test")
            guard fileManager.fileExists(atPath: fileURL.path) else {
                let contents = Data("unimportant".utf8)
                try? contents.write(to: fileURL, options: .completeFileProtectionUntilFirstUserAuthentication)
                // If file doesn't exist, we're at first start, which will be user directed.
                return true
            }
            let contents = try? Data(contentsOf: fileURL)
            return contents != nil
        } catch {
            log.error("Could not create after first unlock test file: %@", String(describing: error))
        }
        return false
    }
}

// MARK: - ViewControllerProvider

extension LoopAppManager: ViewControllerProvider {
    var viewController: UIViewController? {
        get { window?.rootViewController }
        set { window?.rootViewController = newValue }
    }
}

// MARK: - DeviceOrientationController

extension LoopAppManager: DeviceOrientationController {
    func setDefaultSupportedInferfaceOrientations() {
        supportedInterfaceOrientations = Self.defaultSupportedInterfaceOrientations
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension LoopAppManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        switch notification.request.identifier {
        // TODO: Until these notifications are converted to use the new alert system, they shall still show in the foreground
        case LoopNotificationCategory.bolusFailure.rawValue,
             LoopNotificationCategory.pumpBatteryLow.rawValue,
             LoopNotificationCategory.pumpExpired.rawValue,
             LoopNotificationCategory.pumpFault.rawValue:
            completionHandler([.badge, .sound, .alert])
        default:
            // All other userNotifications are not to be displayed while in the foreground
            completionHandler([])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case NotificationManager.Action.retryBolus.rawValue:
            if  let units = response.notification.request.content.userInfo[LoopNotificationUserInfoKey.bolusAmount.rawValue] as? Double,
                let startDate = response.notification.request.content.userInfo[LoopNotificationUserInfoKey.bolusStartDate.rawValue] as? Date,
                startDate.timeIntervalSinceNow >= TimeInterval(minutes: -5)
            {
                deviceDataManager?.analyticsServicesManager.didRetryBolus()

                deviceDataManager?.enactBolus(units: units, at: startDate) { (_) in
                    completionHandler()
                }
                return
            }
        case NotificationManager.Action.acknowledgeAlert.rawValue:
            let userInfo = response.notification.request.content.userInfo
            if let alertIdentifier = userInfo[LoopNotificationUserInfoKey.alertTypeID.rawValue] as? Alert.AlertIdentifier,
               let managerIdentifier = userInfo[LoopNotificationUserInfoKey.managerIDForAlert.rawValue] as? String {
                alertManager?.acknowledgeAlert(identifier: Alert.Identifier(managerIdentifier: managerIdentifier, alertIdentifier: alertIdentifier))
            }
        default:
            break
        }

        completionHandler()
    }
}
