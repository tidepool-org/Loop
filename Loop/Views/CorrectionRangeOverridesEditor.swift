//
//  CorrectionRangeOverridesEditor.swift
//  Loop
//
//  Created by Michael Pangburn on 5/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit
import LoopKitUI


struct CorrectionRangeOverrides: Equatable {
    var preMeal: ClosedRange<HKQuantity>?
    var workout: ClosedRange<HKQuantity>?

    init(preMeal: DoubleRange?, workout: DoubleRange?, unit: HKUnit) {
        self.preMeal = preMeal?.quantityRange(for: unit)
        self.workout = workout?.quantityRange(for: unit)
    }
}

struct CorrectionRangeOverridesEditor: View {
    var initialValue: CorrectionRangeOverrides
    var unit: HKUnit
    var minValue: HKQuantity?
    var save: (_ overrides: CorrectionRangeOverrides) -> Void

    @State var value: CorrectionRangeOverrides

    @State var rangeBeingEdited: WritableKeyPath<CorrectionRangeOverrides, ClosedRange<HKQuantity>?>? {
        didSet {
            if let rangeBeingEdited = rangeBeingEdited, value[keyPath: rangeBeingEdited] == nil {
                value[keyPath: rangeBeingEdited] = guardrail.recommendedBounds // TODO: assign based on rangeBeingEdited
            }
        }
    }

    @State var showingConfirmationAlert = false
    @Environment(\.dismiss) var dismiss

    let guardrail = Guardrail.correctionRange

    init(
        value: CorrectionRangeOverrides,
        unit: HKUnit,
        minValue: HKQuantity?,
        onSave save: @escaping (_ overrides: CorrectionRangeOverrides) -> Void
    ) {
        self._value = State(initialValue: value)
        self.initialValue = value
        self.unit = unit
        self.minValue = minValue
        self.save = save
    }

    var body: some View {
        ConfigurationPage(
            title: Text("Correction Range Overrides", comment: "Title for correction range overrides page"),
            isSaveButtonEnabled: value != initialValue,
            sections: [
                CardListSection(
                    icon: Image("Pre-Meal").renderingMode(.template).foregroundColor(Color(.COBTintColor)),
                    title: Text("Pre-Meal", comment: "Title for pre-meal mode configuration section"),
                    cards: {
                        // TODO: Remove conditional when Swift 5.3 ships
                        // https://bugs.swift.org/browse/SR-11628
                        if true { preMealModeCard }
                    }
                ),
                CardListSection(
                    icon: Image("workout").foregroundColor(Color(.glucoseTintColor)),
                    title: Text("Workout", comment: "Title for workout mode configuration section"),
                    cards: {
                        // TODO: Remove conditional when Swift 5.3 ships
                        // https://bugs.swift.org/browse/SR-11628
                        if true { workoutModeCard }
                    }
                )
            ],
            actionAreaContent: {
                guardrailWarningIfNecessary
            },
            onSave: {
                if self.crossedThresholds.isEmpty {
                    self.saveAndDismiss()
                } else {
                    self.showingConfirmationAlert = true
                }
            }
        )
        .alert(isPresented: $showingConfirmationAlert, content: confirmationAlert)
    }

    private func card(
        for rangeKeyPath: WritableKeyPath<CorrectionRangeOverrides, ClosedRange<HKQuantity>?>,
        defaultValue: ClosedRange<HKQuantity>,
        description: Text
    ) -> Card {
        Card {
            SettingDescription(text: description)
            SingleValueSetting(
                isEditing: Binding(
                    get: { self.rangeBeingEdited == rangeKeyPath },
                    set: { isEditing in
                        withAnimation {
                            self.rangeBeingEdited = isEditing ? rangeKeyPath : nil
                        }
                    }
                ),
                valueContent: {
                    GuardrailConstrainedQuantityRangeView(
                        range: value[keyPath: rangeKeyPath],
                        unit: unit,
                        guardrail: guardrail,
                        isEditing: rangeBeingEdited == rangeKeyPath,
                        forceDisableAnimations: true
                    )
                },
                valuePicker: {
                    GlucoseRangePicker(
                        range: Binding(
                            get: { self.value[keyPath: rangeKeyPath] ?? defaultValue },
                            set: { newValue in
                                withAnimation {
                                    self.value[keyPath: rangeKeyPath] = newValue
                                }
                            }
                        ),
                        unit: unit,
                        minValue: minValue,
                        guardrail: guardrail
                    )
                }
            )
        }
    }

    private var preMealModeCard: Card {
        card(
            for: \.preMeal,
            defaultValue: guardrail.recommendedBounds, // TODO: what's appropriate here?
            description: Text("When Pre-Meal Mode is active, the app adjusts insulin delivery in an effort to bring your glucose into your pre-meal correction range.", comment: "Description of pre-meal mode")
        )
    }

    private var workoutModeCard: Card {
        card(
            for: \.workout,
            defaultValue: guardrail.recommendedBounds, // TODO: what's appropriate here?
            description: Text("When Workout Mode is active, the app adjusts insulin delivery in an effort to bring your glucose into your workout correction range.", comment: "Description of workout mode")
        )
    }

    private var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.crossedThresholds
        return Group {
            if !crossedThresholds.isEmpty {
                CorrectionRangeOverridesGuardrailWarning(crossedThresholds: crossedThresholds)
            }
        }
    }

    private var crossedThresholds: [SafetyClassification.Threshold] {
        return [value.preMeal, value.workout]
            .compactMap { $0 }
            .flatMap { [$0.lowerBound, $0.upperBound] }
            .compactMap { bound in
                switch guardrail.classification(for: bound) {
                case .withinRecommendedRange:
                    return nil
                case .outsideRecommendedRange(let threshold):
                    return threshold
                }
            }
    }

    private func confirmationAlert() -> Alert {
        Alert(
            title: Text("Save Correction Range Overrides?", comment: "Alert title for confirming correction range overrides outside the recommended range"),
            message: Text("One or more of the values you have entered are outside of what Tidepool generally recommends.", comment: "Alert message for confirming correction range overrides outside the recommended range"),
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

private struct CorrectionRangeOverridesGuardrailWarning: View {
    var crossedThresholds: [SafetyClassification.Threshold]

    var body: some View {
        assert(!crossedThresholds.isEmpty)
        return GuardrailWarning(
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
