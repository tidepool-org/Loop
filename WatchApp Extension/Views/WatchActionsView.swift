//
//  WatchActionsView.swift
//  Loop
//
//  Created by Pete Schwamb on 8/15/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


import SwiftUI
import LoopKit
import LoopCore

struct WatchActionsView: View {
    @State private var loopManager = ExtensionDelegate.shared().loopManager

    @State private var isShowingPresetList: Bool = false
    @State private var isShowingActivePreset: Bool = false

    var presetActive: Bool {
        return loopManager.watchInfo.scheduleOverride?.isActive() == true
    }

    var body: some View {
        ScrollView(.vertical) {
            LoopHeader()

            HStack(spacing: 0) {
                CircleTintedButton(
                    label: "Carbs",
                    image: Image("carbs"),
                    foregroundTint: .carbs,
                    backgroundTint: .darkCarbs
                ) {
                    loopManager.bolusViewModel = CarbAndBolusFlowViewModel(configuration: .carbEntry(nil))
                }
                CircleTintedButton(
                    label: "Bolus",
                    image: Image("bolus"),
                    foregroundTint: .insulin,
                    backgroundTint: .darkInsulin
                ) {
                    loopManager.bolusViewModel = CarbAndBolusFlowViewModel(configuration: .manualBolus)
                }
            }
            .padding(.bottom, 4)
            HStack {
                CircleTintedButton(
                    label: "Presets",
                    image: Image("presets"),
                    foregroundTint: presetActive ? .darkPresets : .presets,
                    backgroundTint: presetActive ? .presets : .darkPresets
                ) {
                    if presetActive {
                        isShowingActivePreset = true
                    } else {
                        isShowingPresetList = true
                    }
                }
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 14, weight: .light))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingPresetList) {
            PresetListView(presets: loopManager.selectablePresets)
        }
        .sheet(isPresented: $isShowingActivePreset) {
            if let activeOverride = loopManager.watchInfo.scheduleOverride, activeOverride.isActive() {
                ActiveOverrideView(override: activeOverride)
            } else {
                Text("Preset override not active")
            }
        }
        .sheet(isPresented:Binding(
            get: { loopManager.bolusViewModel != nil },
            set: { if !$0 { loopManager.bolusViewModel = nil } }
        )) {
            CarbAndBolusFlow(viewModel: loopManager.bolusViewModel!)
        }
        .onChange(of: loopManager.watchInfo.scheduleOverride, { oldValue, newValue in
            if oldValue == nil && newValue != nil {
                // Preset activated
                isShowingPresetList = false
                isShowingActivePreset = true
            }
            if oldValue != nil && newValue == nil && isShowingActivePreset {
                isShowingActivePreset = false
            }

        })
        .environment(\.glucoseDisplayUnit, loopManager.displayGlucoseUnit)
    }

}
