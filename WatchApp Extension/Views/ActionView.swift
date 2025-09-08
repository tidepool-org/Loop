//
//  ActionView.swift
//  Loop
//
//  Created by Pete Schwamb on 8/15/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


import SwiftUI
import LoopKit

struct ActionView: View {
    @State private var loopManager = ExtensionDelegate.shared().loopManager

    var freshness: LoopCompletionFreshness {
        return LoopCompletionFreshness(lastCompletion: loopManager.activeContext?.loopLastRunDate, at: Date())
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

                    if let eventualGlucose = activeContext.eventualGlucose,
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
                    // Handle action
                }
                CircleTintedButton(
                    label: "Bolus",
                    image: Image("bolus"),
                    foregroundTint: .insulin,
                    backgroundTint: .darkInsulin
                ) {
                    // Handle action
                }
            }
            .padding(.bottom, 4)
            HStack {
                CircleTintedButton(
                    label: "Presets",
                    image: Image("presets"),
                    foregroundTint: .presets,
                    backgroundTint: .darkPresets
                ) {
                    // Handle action
                }
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 14, weight: .light))
        .toolbar(.hidden, for: .navigationBar)
    }
}
