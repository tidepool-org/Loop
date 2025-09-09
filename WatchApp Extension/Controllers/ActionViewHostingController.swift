//
//  ActionViewHostingController.swift
//  Loop
//
//  Created by Pete Schwamb on 8/15/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import WatchKit
import SwiftUI

class ActionViewHostingController: WKHostingController<WatchActionsView> {
    
    override var body: WatchActionsView {
        return WatchActionsView()
    }
}
