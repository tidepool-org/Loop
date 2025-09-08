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
            Button("Action 1") {
                // Handle action
            }
            Button("Action 2") {
                // Handle action
            }
            Button("Action 3") {
                // Handle action
            }
            Button("Action 4") {
                // Handle action
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
