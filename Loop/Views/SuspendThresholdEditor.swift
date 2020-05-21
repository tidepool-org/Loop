//
//  SuspendThresholdEditor.swift
//  Loop
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit
import LoopKitUI


extension Guardrail where Value == HKQuantity {
    static let suspendThreshold = Guardrail(absoluteBounds: 54...180, recommendedBounds: 71...120, unit: .milligramsPerDeciliter)
}

struct SuspendThresholdEditor: View {
    var initialValue: HKQuantity?
    var unit: HKUnit
    var maxValue: HKQuantity?
    var save: (_ suspendThreshold: HKQuantity) -> Void

    @State var value: HKQuantity
    @State var isEditing = false
    @State var showingConfirmationAlert = false
    @Environment(\.dismiss) var dismiss

    let guardrail = Guardrail.suspendThreshold

    init(
        value: HKQuantity?,
        unit: HKUnit,
        maxValue: HKQuantity?,
        onSave save: @escaping (_ suspendThreshold: HKQuantity) -> Void
    ) {
        self._value = State(initialValue: value ?? Self.defaultValue(for: unit))
        self.initialValue = value
        self.unit = unit
        self.maxValue = maxValue
        self.save = save
    }

    private static func defaultValue(for unit: HKUnit) -> HKQuantity {
        switch unit {
        case .milligramsPerDeciliter:
            return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)
        case .millimolesPerLiter:
            return HKQuantity(unit: .millimolesPerLiter, doubleValue: 4.5)
        default:
            fatalError("Unsupported glucose unit \(unit)")
        }
    }

    var body: some View {
        ConfigurationPage(
            title: Text("Suspend Threshold", comment: "Title for suspend threshold configuration page"),
            isSaveButtonEnabled: isSaveButtonEnabled,
            cards: {
                // TODO: Remove conditional when Swift 5.3 ships
                // https://bugs.swift.org/browse/SR-11628
                if true {
                    Card {
                        SettingDescription(text: description)
                        ExpandableSetting(
                            isEditing: $isEditing,
                            valueContent: {
                                GuardrailConstrainedQuantityView(
                                    value: value,
                                    unit: unit,
                                    guardrail: guardrail,
                                    isEditing: isEditing,
                                    // Workaround for strange animation behavior on appearance
                                    forceDisableAnimations: true
                                )
                            },
                            expandedContent: {
                                GlucoseValuePicker(
                                    value: $value.animation(),
                                    unit: unit,
                                    guardrail: guardrail,
                                    bounds: guardrail.absoluteBounds.lowerBound...(maxValue ?? guardrail.absoluteBounds.upperBound)
                                )
                            }
                        )
                    }
                }
            },
            actionAreaContent: {
                if warningThreshold != nil {
                    SuspendThresholdGuardrailWarning(safetyClassificationThreshold: warningThreshold!)
                }
            },
            onSave: {
                if self.warningThreshold == nil {
                    self.saveAndDismiss()
                } else {
                    self.showingConfirmationAlert = true
                }
            }
        )
        .alert(isPresented: $showingConfirmationAlert, content: confirmationAlert)
    }

    var description: Text {
        Text("When your glucose is predicted to go below this value, the app will recommend a basal rate of 0 U/h and will not recommend a bolus.", comment: "Suspend threshold description")
    }

    private var isSaveButtonEnabled: Bool {
        initialValue == nil || value != initialValue!
    }

    private var warningThreshold: SafetyClassification.Threshold? {
        switch guardrail.classification(for: value) {
        case .withinRecommendedRange:
            return nil
        case .outsideRecommendedRange(let threshold):
            return threshold
        }
    }

    private func confirmationAlert() -> Alert {
        Alert(
            title: Text("Save Suspend Threshold?", comment: "Alert title for confirming a suspend threshold outside the recommended range"),
            message: Text("The suspend threshold you have entered is outside of what Tidepool generally recommends.", comment: "Alert message for confirming a suspend threshold outside the recommended range"),
            primaryButton: .cancel(Text("Go Back")),
            secondaryButton: .default(
                Text("Continue"),
                action: saveAndDismiss
            )
        )
    }

    private func saveAndDismiss() {
        save(value)
        dismiss()
    }
}

struct SuspendThresholdGuardrailWarning: View {
    var safetyClassificationThreshold: SafetyClassification.Threshold

    var body: some View {
        GuardrailWarning(title: title, threshold: safetyClassificationThreshold)
    }

    private var title: Text {
        switch safetyClassificationThreshold {
        case .minimum, .belowRecommended:
            return Text("Low Suspend Threshold", comment: "Title text for the low suspend threshold warning")
        case .aboveRecommended, .maximum:
            return Text("High Suspend Threshold", comment: "Title text for the high suspend threshold warning")
        }
    }
}

struct SuspendThresholdView_Previews: PreviewProvider {
    static var previews: some View {
        SuspendThresholdEditor(value: nil, unit: .milligramsPerDeciliter, maxValue: nil, onSave: { _ in })
    }
}
