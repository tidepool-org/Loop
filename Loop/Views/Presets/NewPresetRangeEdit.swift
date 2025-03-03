//
//  CreatePresetEditRangeView.swift
//  Loop
//
//  Created by Pete Schwamb on 2/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKit
import LoopKitUI

struct NewPresetRangeEdit: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var range: ClosedRange<LoopQuantity>?
    var guardrail: Guardrail<LoopQuantity>
    private var scheduledRange: ClosedRange<LoopQuantity>
    @State private var editedRange: ClosedRange<LoopQuantity>?

    init(range: Binding<ClosedRange<LoopQuantity>?>, guardrail: Guardrail<LoopQuantity>, scheduledRange: ClosedRange<LoopQuantity>) {
        self._range = range
        self.guardrail = guardrail
        self.scheduledRange = scheduledRange
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                PresetRangeEditor(range:
                    Binding(
                        get: { editedRange ?? range },
                        set: { editedRange = $0 }),
                    guardrail: guardrail,
                    scheduledRange: scheduledRange
                )
            }
            actionArea
        }
        .navigationBarBackButtonHidden(editedRange != nil)
        .navigationBarItems(
            trailing: cancelButton
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Edit Preset")
        .edgesIgnoringSafeArea(.bottom)
    }

    private var cancelButton: some View {
        Group {
            if editedRange != nil {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
        }
    }


    private var actionArea: some View {
        VStack(spacing: 0) {
            guardrailWarningIfNecessary
            actionButton
        }
        .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
    }

    private var actionButton: some View {
        Button("Save") {
            range = editedRange
            dismiss()
        }
        .disabled(editedRange == nil)
        .buttonStyle(ActionButtonStyle(.primary))
        .padding()
    }


    var crossedThresholds: [SafetyClassification.Threshold] {
        if let range = editedRange ?? range {
            let lowerBound = range.lowerBound
            let upperBound = range.upperBound
            return [lowerBound, upperBound].compactMap { (bound) -> SafetyClassification.Threshold? in
                switch guardrail.classification(for: bound) {
                case .withinRecommendedRange:
                    return nil
                case .outsideRecommendedRange(let threshold):
                    return threshold
                }
            }
        } else {
            return []
        }
    }

    var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.crossedThresholds
        return Group {
            if !crossedThresholds.isEmpty {
                CorrectionRangeGuardrailWarning(crossedThresholds: crossedThresholds)
            }
        }.padding()
    }
}

private struct CorrectionRangeGuardrailWarning: View {
    var crossedThresholds: [SafetyClassification.Threshold]

    var body: some View {
        assert(!crossedThresholds.isEmpty)
        return GuardrailWarning(
            therapySetting: .glucoseTargetRange,
            title: crossedThresholds.count == 1 ? singularWarningTitle(for: crossedThresholds.first!) : multipleWarningTitle,
            thresholds: crossedThresholds
        )
    }

    private func singularWarningTitle(for threshold: SafetyClassification.Threshold) -> Text {
        switch threshold {
        case .minimum, .belowRecommended:
            return Text("Low Correction Value", comment: "Title text for the low correction value warning")
        case .aboveRecommended, .maximum:
            return Text("High Correction Value", comment: "Title text for the high correction value warning")
        }
    }

    private var multipleWarningTitle: Text {
        Text("Correction Values", comment: "Title text for multi-value correction value warning")
    }
}
