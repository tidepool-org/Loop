//
//  ChartPageView.swift
//  Loop
//
//  Created by Pete Schwamb on 9/19/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopCore
import SpriteKit

struct ChartPageView: View {
    @Environment(\.sizeClass) private var sizeClass

    @State private var loopManager = ExtensionDelegate.shared().loopManager

    @State private var isShowingPresetList: Bool = false
    @State private var isShowingActivePreset: Bool = false

    var presetActive: Bool {
        return loopManager.watchInfo.scheduleOverride?.isActive() == true
    }

    private let glucoseChartScene: GlucoseChartScene = {
        let s = GlucoseChartScene()
        s.size = WKInterfaceDevice.current().screenBounds.size
        return s
    }()

    private var chartHeight: CGFloat {
        switch sizeClass {
        case .size38mm:
            return 73
        case .size44mm:
            return 111
        case .size45mm:
            return 115
        default:
            return 90
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            LoopHeader()

            SpriteView(scene: glucoseChartScene)
                .frame(height: chartHeight)
                .ignoresSafeArea()
                .gesture(
                    // Handle double tap
                    TapGesture(count: 2)
                        .onEnded {
                            glucoseChartScene.increaseVisibleDuration()
                        }
                )
                .gesture(
                    // Handle single tap
                    TapGesture()
                        .onEnded {
                            glucoseChartScene.decreaseVisibleDuration()
                        }
                )
        }
        .font(.system(size: 14, weight: .light))
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.glucoseDisplayUnit, loopManager.displayGlucoseUnit)
        .onAppear() {
            updateGlucoseChart()
        }
        .onChange(of: loopManager.activeContext?.predictedGlucose) { oldValue, newValue in
            updateGlucoseChart()
        }
    }

    private func updateGlucoseChart() {
        Task { @MainActor in
            let chartData = await loopManager.generateChartData()
            glucoseChartScene.data = chartData
            glucoseChartScene.setNeedsUpdate()
        }
    }

}
