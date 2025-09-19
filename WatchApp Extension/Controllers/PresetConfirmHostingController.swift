//
//  PresetConfirmHostingController.swift
//  Loop
//
//  Created by Pete Schwamb on 9/19/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import WatchKit
import SwiftUI
import LoopCore

class PresetConfirmHostingController: WKHostingController<PresetDetailView> {
    override var body: PresetDetailView {
        return PresetDetailView(preset: ExtensionDelegate.shared().loopManager.pendingPreset)
    }
}
