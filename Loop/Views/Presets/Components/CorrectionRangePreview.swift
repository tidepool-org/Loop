//
//  CorrectionRangePreview.swift
//  Loop
//
//  Created by Pete Schwamb on 3/7/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKit
import LoopKitUI

public struct CorrectionRangePreview: View {
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.guidanceColors) private var guidanceColors

    var range: ClosedRange<LoopQuantity>?
    var guardrail: Guardrail<LoopQuantity>
    private var scheduledRange: ClosedRange<LoopQuantity>
    var showDisclosure: Bool

    init(range: ClosedRange<LoopQuantity>?, guardrail: Guardrail<LoopQuantity>, scheduledRange: ClosedRange<LoopQuantity>, showDisclosure: Bool = false) {
        self.range = range
        self.guardrail = guardrail
        self.scheduledRange = scheduledRange
        self.showDisclosure = showDisclosure
    }

    func boundText(for bound: LoopQuantity) -> Text {
        let color = guardrail.color(for: bound, guidanceColors: guidanceColors)
        let text = displayGlucosePreference.format(bound, includeUnit: false)
        switch guardrail.classification(for: bound) {
        case .withinRecommendedRange:
            return Text(text)
                .foregroundColor(.accentColor)
                .font(.system(size: 34, weight: .bold))
        case .outsideRecommendedRange:
            return (
                Text(text)
                    .foregroundColor(color)
                    .font(.system(size: 34, weight: .bold))
                )
        }
    }

    func correctionRangeLabel(range: ClosedRange<LoopQuantity>) -> Text {
        boundText(for: range.lowerBound) +
        Text("-").foregroundColor(.secondary)
            .font(.system(size: 34, weight: .light))
        +
        boundText(for: range.upperBound) +
        Text(" ") +
        Text(displayGlucosePreference.unit.localizedShortUnitString)
            .font(.system(.body))
            .foregroundColor(.secondary)
            .baselineOffset(12)
    }

    private var correctionRangeCrossedThresholds: [SafetyClassification.Threshold] {
        guard let range else { return [] }

        let thresholds: [SafetyClassification.Threshold] = [range.lowerBound, range.upperBound].compactMap { bound in
            switch guardrail.classification(for: bound) {
            case .withinRecommendedRange:
                return nil
            case .outsideRecommendedRange(let threshold):
                return threshold
            }
        }

        return thresholds
    }

    private var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.correctionRangeCrossedThresholds
        let severity = crossedThresholds.map { $0.severity }.max()

        return Group {
            if let severity, !crossedThresholds.isEmpty {
                let color: Color = severity > .default ? guidanceColors.critical : guidanceColors.warning
                HStack(alignment: .top, spacing: 12) {
                    Text(Image(systemName: "exclamationmark.triangle.fill"))
                        .foregroundColor(color)
                    Text(SafetyClassification.captionForCrossedThresholds(crossedThresholds, isRange: true))
                        .accessibilityIdentifier("text_CorrectionRangeWarning");
                }
                .padding(12)
                .background(color.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Text("Correction Range")
                    .font(.headline)
                Spacer()
                if showDisclosure {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }.padding(.bottom, 10)
            VStack(spacing: 4) {
                if let range {
                    correctionRangeLabel(range: range).accessibilityIdentifier("text_CorrectionRangePreview")
                    Text("Adjusted Range")
                } else {
                    correctionRangeLabel(range: scheduledRange).accessibilityIdentifier("text_CorrectionRangePreview")
                    Text("Scheduled Range")
                }
            }
            guardrailWarningIfNecessary
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 5)
                .padding(.horizontal, 2)
        }
        .foregroundColor(.primary)
    }
}
