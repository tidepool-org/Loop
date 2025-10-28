//
//  ExistingPresetInsulinNeedsEdit.swift
//  Loop
//
//  Created by Pete Schwamb on 4/18/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKit
import LoopKitUI

struct ExistingPresetInsulinNeedsEdit: View {
    @Environment(\.dismiss) private var dismiss

    var guardrail: Guardrail<LoopQuantity>
    @Binding var scaleFactor: Double
    @State var editedScale: Double
    var presetUsesScheduledRange: Bool = false

    init(insulinScaleFactor: Binding<Double>, presetUsesScheduledRange: Bool) {

        _scaleFactor = insulinScaleFactor
        editedScale = insulinScaleFactor.wrappedValue
        guardrail = Guardrail.presetInsulinNeeds
        self.presetUsesScheduledRange = presetUsesScheduledRange
    }

    var body: some View {
        CardSectionScrollView {
            CardSection {
                InsulinScaleAdjustView(insulinMultiplier: $editedScale, guardrail: Guardrail.presetInsulinNeeds)
            }
        } actionArea: {
            if let crossedThreshold {
                WarningView(
                    title: crossedThreshold.insulinNeedsScaleWarningTitle,
                    caption: crossedThreshold.insulinNeedsScaleWarningCaption,
                    severity: crossedThreshold.severity
                )
            } else if presetUsesScheduledRange && editedScale == 1 {
                NoticeView(
                    title: Text("Adjust Overall Insulin Needs"),
                    caption: Text("With correction range set to using your scheduled range, overall insulin needs adjustment is required.")
                )
            }
            actionButton
        }
        .navigationBarBackButtonHidden(editedScale != scaleFactor)
        .navigationBarItems(
            trailing: cancelButton
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Edit Preset")
    }

    private var cancelButton: some View {
        Group {
            if editedScale != scaleFactor {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
        }
    }


    private var actionButton: some View {
        Button("Save") {
            scaleFactor = editedScale
            dismiss()
        }
        .disabled(editedScale == scaleFactor || (editedScale == 1 && presetUsesScheduledRange))
        .buttonStyle(ActionButtonStyle(.primary))
    }

    var crossedThreshold: SafetyClassification.Threshold? {
        switch guardrail.classification(for: LoopQuantity(unit: .percent, doubleValue: editedScale * 100)) {
        case .withinRecommendedRange:
            return nil
        case .outsideRecommendedRange(let threshold):
            return threshold
        }
    }
}
