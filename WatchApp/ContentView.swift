//
//  WatchAppContent.swift
//  Loop
//
//  Created by Pete Schwamb on 9/21/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopCore

struct ContentView: View {
    @Environment(LoopDataManager.self) var loopManager

    @State private var presetToConfirm: SelectablePreset? = nil
    @State private var selectedPage = UserDefaults.standard.startOnChartPage ? 1 : 0

    var body: some View {
        VStack {
            // TabView for swipeable pages
            TabView(selection: $selectedPage) {
                WatchActionsView()
                    .tag(0)

                ChartPageView()
                    .tag(1)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .automatic))
        }
        .onChange(of: loopManager.pendingPresetReminder) { oldValue, newValue in
            if oldValue == nil, newValue != nil {
                presetToConfirm = loopManager.pendingPreset
            }
        }
        .sheet(item: $presetToConfirm) { preset in
            PresetConfirmationView(preset: preset)
        }
        .onChange(of: selectedPage, { oldValue, newValue in
            UserDefaults.standard.startOnChartPage = selectedPage == 1
        })
    }
}


#Preview {
    ContentView()
}
