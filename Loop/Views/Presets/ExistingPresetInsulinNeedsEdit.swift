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

    init(insulinScaleFactor: Binding<Double>) {

        _scaleFactor = insulinScaleFactor
        editedScale = insulinScaleFactor.wrappedValue
        guardrail = Guardrail.presetInsulinNeeds
    }

    var body: some View {
        CardSectionScrollView {
            CardSection {
                InsulinScaleAdjustView(insulinMultiplier: $editedScale)
            }
        } actionArea: {
            guardrailWarningIfNecessary
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
        .disabled(editedScale == scaleFactor)
        .buttonStyle(ActionButtonStyle(.primary))
        .padding()
    }

    var crossedThreshold: SafetyClassification.Threshold? {
        switch guardrail.classification(for: LoopQuantity(unit: .percent, doubleValue: editedScale * 100)) {
        case .withinRecommendedRange:
            return nil
        case .outsideRecommendedRange(let threshold):
            return threshold
        }
    }

    var guardrailWarningIfNecessary: some View {
        return Group {
            if let crossedThreshold {
                WarningView(
                    title: crossedThreshold.insulinNeedsScaleWarningTitle,
                    caption: crossedThreshold.insulinNeedsScaleWarningCaption,
                    severity: crossedThreshold.severity
                )
            }
        }.padding()
    }
}
