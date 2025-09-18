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

    var presentAddCarbUI: () -> Void
    var presentSetBolusUI: () -> Void

    var freshness: LoopCompletionFreshness {
        return LoopCompletionFreshness(lastCompletion: loopManager.activeContext?.loopLastRunDate, at: Date())
    }

    var presetActive: Bool {
        return loopManager.watchInfo.scheduleOverride?.isActive() == true
    }

    var glucoseValue: String {
        guard let activeContext = loopManager.activeContext,
              let glucose = activeContext.glucose,
              let unit = activeContext.displayGlucoseUnit else
        {
            return "- - -"
        }

        let formatter = NumberFormatter.glucoseFormatter(for: unit)

        var glucoseValue: String

        if let glucoseCondition = activeContext.glucoseCondition {
            glucoseValue = glucoseCondition.localizedDescription
        } else {
            glucoseValue = formatter.string(from: glucose.doubleValue(for: unit)) ?? "???"
        }

        let trend = activeContext.glucoseTrend?.symbol ?? ""
        return glucoseValue + trend
    }

    var body: some View {
        ScrollView(.vertical) {
            HStack {
                if let activeContext = loopManager.activeContext,
                   let unit = activeContext.displayGlucoseUnit
                {
                    LoopCircleView(closedLoop: activeContext.isClosedLoop ?? false, freshness: freshness)
                        .frame(width: 22, height: 22)
                        .padding(.horizontal)

                    Text(glucoseValue)

                    Spacer()

                    if FeatureFlags.showEventualBloodGlucoseOnWatchEnabled,
                       let eventualGlucose = activeContext.eventualGlucose,
                       let eventualGlucoseValue = NumberFormatter.glucoseFormatter(for: unit).string(from: eventualGlucose.doubleValue(for: unit))
                    {
                        Text(eventualGlucoseValue)
                    }
                }
            }
            .font(.system(size: 24, weight: .light))

            HStack(spacing: 0) {
                CircleTintedButton(
                    label: "Carbs",
                    image: Image("carbs"),
                    foregroundTint: .carbs,
                    backgroundTint: .darkCarbs
                ) {
                    presentAddCarbUI()
                }
                CircleTintedButton(
                    label: "Bolus",
                    image: Image("bolus"),
                    foregroundTint: .insulin,
                    backgroundTint: .darkInsulin
                ) {
                    presentSetBolusUI()
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
        .sheet(isPresented: Binding(
            get: { loopManager.pendingScheduledPresetActivationId != nil },
            set: { if !$0 { loopManager.pendingScheduledPresetActivationId = nil } }
        )) {
            // This is for confirming preset activation from scheduled notification
            if let preset = loopManager.selectablePresets.first(where: { $0.id == loopManager.pendingScheduledPresetActivationId })
            {
                PresetDetailView(preset: preset)
            } else {
                Text("Invalid preset activation id")
            }
        }
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
        .onChange(of: loopManager.watchInfo.scheduleOverride, { oldValue, newValue in
            if oldValue == nil && newValue != nil {
                // Preset activated
                isShowingPresetList = false
                isShowingActivePreset = true
                loopManager.pendingScheduledPresetActivationId = nil
            }
            if oldValue != nil && newValue == nil && isShowingActivePreset {
                isShowingActivePreset = false
            }

        })
        .environment(\.glucoseDisplayUnit, loopManager.displayGlucoseUnit)
    }
}
