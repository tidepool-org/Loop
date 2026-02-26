//
//  LoopWatchApp.swift
//  Loop
//
//  Created by Pete Schwamb on 9/21/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//
import SwiftUI

@main
struct LoopWatchApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) private var appDelegate

    var loopManager = LoopDataManager.shared

    var body: some Scene {
        WindowGroup {
            if loopManager.activeContext?.isOnboardingCompleted != true {
                CompleteOnboardingView()
            } else {
                ContentView()
                    .environment(loopManager)
            }
        }
    }
}
