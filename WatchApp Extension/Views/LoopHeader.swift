//
//  Untitled.swift
//  Loop
//
//  Created by Pete Schwamb on 9/20/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopCore

struct LoopHeader: View {
    @Environment(LoopDataManager.self) var loopManager

    var freshness: LoopCompletionFreshness {
        return LoopCompletionFreshness(lastCompletion: loopManager.activeContext?.loopLastRunDate, at: Date())
    }

    var body: some View {
        HStack {
            if let activeContext = loopManager.activeContext,
               let unit = activeContext.displayGlucoseUnit
            {
                LoopCircleView(closedLoop: activeContext.isClosedLoop ?? false, freshness: freshness)
                    .frame(width: 22, height: 22)
                    .padding(.horizontal)
                
                Text(loopManager.glucoseValue)
                
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
    }
}
