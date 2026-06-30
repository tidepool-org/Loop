//
//  SceneDelegate.swift
//  Loop
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit

/// Drives the window-tied lifecycle for the app under the UIScene life cycle.
///
/// The window is created automatically by UIKit from `Main.storyboard` (declared
/// via `UISceneStoryboardFile` in the scene manifest) and assigned to `window`
/// before `scene(_:willConnectTo:options:)` is called. The shared `LoopAppManager`
/// continues to be owned by `AppDelegate` so that application-level callbacks
/// (remote notifications, protected data) can reach it.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate, WindowProvider {

    var window: UIWindow?

    private let log = DiagnosticLog(category: "SceneDelegate")

    private var loopAppManager: LoopAppManager? {
        (UIApplication.shared.delegate as? AppDelegate)?.loopAppManager
    }

    // MARK: - UIWindowSceneDelegate - Connection

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        log.default(#function)

        // Avoid doing full initialization when running tests.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let loopAppManager = appDelegate.loopAppManager

        // The app manager only initializes once per process. Multiple scenes are not
        // supported, so guard against a scene reconnecting after initialization.
        guard loopAppManager.isInInitialState else {
            return
        }

        loopAppManager.initialize(windowProvider: self, launchOptions: appDelegate.launchOptions)
        loopAppManager.launch()

        // Handle any URLs or user activities delivered at connection time.
        if let url = connectionOptions.urlContexts.first?.url {
            _ = loopAppManager.handle(url)
        }
        for userActivity in connectionOptions.userActivities {
            _ = loopAppManager.userActivity(userActivity, restorationHandler: { _ in })
        }
    }

    // MARK: - UIWindowSceneDelegate - Life Cycle

    func sceneDidBecomeActive(_ scene: UIScene) {
        log.default(#function)

        loopAppManager?.didBecomeActive()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        log.default(#function)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        log.default(#function)

        // Unlike the legacy `applicationWillEnterForeground(_:)`, this is also called as
        // part of cold launch, before the managers are initialized. `resumeLaunch()`
        // performs this check itself once launch completes, so here it only applies to
        // subsequent foreground transitions.
        guard let loopAppManager, loopAppManager.isLaunchComplete else {
            return
        }
        loopAppManager.askUserToConfirmLoopReset()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        log.default(#function)
    }

    // MARK: - UIWindowSceneDelegate - Deeplinking

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        _ = loopAppManager?.handle(url)
    }

    // MARK: - UIWindowSceneDelegate - Continuity

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        log.default(#function)

        _ = loopAppManager?.userActivity(userActivity, restorationHandler: { _ in })
    }
}
