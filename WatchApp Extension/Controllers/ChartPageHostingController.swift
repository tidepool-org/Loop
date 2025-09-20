//
//  ChartPageHostingController.swift
//  Loop
//
//  Created by Pete Schwamb on 9/19/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import WatchKit
import SwiftUI

class ChartPageHostingController: WKHostingController<ChartPageView> {
    override var body: ChartPageView {
        return ChartPageView()
    }
}
