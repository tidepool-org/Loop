//
//  InsulinNeedsAdjustmentPreview.swift
//  Loop
//
//  Created by Pete Schwamb on 10/6/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKit
import LoopKitUI

public struct InsulinNeedsAdjustmentPreview: View {
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.guidanceColors) private var guidanceColors

    var range: ClosedRange<LoopQuantity>?
    var guardrail: Guardrail<LoopQuantity>
    private var insulinPercentage: Double
    var showDisclosure: Bool

    init(insulinPercentage: Double, guardrail: Guardrail<LoopQuantity>, showDisclosure: Bool = false) {
        self.insulinPercentage = insulinPercentage
        self.guardrail = guardrail
        self.showDisclosure = showDisclosure
    }

    var valueColor: Color {
        switch Guardrail.presetInsulinNeeds.classification(for: .init(unit: .percent, doubleValue: insulinPercentage)) {
        case .withinRecommendedRange:
            return .accentColor
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .minimum, .maximum:
                return guidanceColors.critical
            case .belowWarning, .aboveWarning:
                return guidanceColors.critical
            case .belowRecommended, .aboveRecommended:
                return guidanceColors.warning
            }
        }
    }

    private var guardrailWarningIfNecessary: some View {

        let classification = Guardrail.presetInsulinNeeds.classification(for: .init(unit: .percent, doubleValue: insulinPercentage))

        return Group {
            if case .outsideRecommendedRange(let threshold) = classification {
                let severity = threshold.severity
                let color: Color = severity > .default ? guidanceColors.critical : guidanceColors.warning
                HStack(alignment: .top, spacing: 12) {
                    Text(Image(systemName: "exclamationmark.triangle.fill"))
                        .foregroundColor(color)
                    Text(SafetyClassification.captionForCrossedThresholds([threshold], isRange: true))
                        .accessibilityIdentifier("text_InsulinNeedsWarning");
                }
                .padding(12)
                .background(color.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack {
                Text("Overall Insulin")
                    .font(.headline)
                Spacer()
                if showDisclosure {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }.padding(.bottom, 10)
            Text("\(Int(insulinPercentage))%")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(valueColor)
            Text("of scheduled")
            guardrailWarningIfNecessary
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 5)
                .padding(.horizontal, 2)
        }
        .foregroundColor(.primary)
    }
}
