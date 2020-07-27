//
//  BolusEntryView.swift
//  Loop
//
//  Created by Michael Pangburn on 7/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import HealthKit
import SwiftUI
import LoopKit
import LoopKitUI
import LoopUI


struct BolusEntryView: View, HorizontalSizeClassOverride {
    @ObservedObject var viewModel: BolusEntryViewModel

    @State private var enteredBolusAmount = ""

    @State private var isManualGlucoseEntryEnabled = false
    @State private var enteredManualGlucose = ""

    @State private var isInteractingWithChart = false
    @State private var isKeyboardVisible = false

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            List {
                historySection
                summarySection
            }
            .padding(.top, -28) // Bring the top card up closer to the navigation bar
            .listStyle(GroupedListStyle())
            .environment(\.horizontalSizeClass, horizontalOverride)

            actionArea
                .frame(height: isKeyboardVisible ? 0 : nil)
                .opacity(isKeyboardVisible ? 0 : 1)
        }
        .onKeyboardStateChange { state in
            self.isKeyboardVisible = state.height > 0
        }
        .keyboardAware()
        .edgesIgnoringSafeArea(isKeyboardVisible ? [] : .bottom)
        .navigationBarTitle(viewModel.potentialCarbEntry == nil ? Text("Bolus", comment: "Title for bolus entry screen") : Text("Meal Bolus", comment: "Title for bolus entry screen when also entering carbs"))
        .alert(item: $viewModel.activeAlert, content: alert(for:))
        .onReceive(viewModel.$enteredBolus) { updatedBolusEntry in
            // The view model can update the user's entered bolus when the recommendation changes; ensure the text entry updates in tandem.
            let amount = updatedBolusEntry.doubleValue(for: .internationalUnit())
            self.enteredBolusAmount = amount == 0 ? "" : Self.doseAmountFormatter.string(from: amount) ?? String(amount)
        }
    }

    private var historySection: some View {
        Section {
            VStack(spacing: 8) {
                HStack {
                    activeCarbsLabel
                    Spacer()
                    activeInsulinLabel
                }

                // Use a ZStack to allow horizontally clipping the predicted glucose chart,
                // without clipping the point label on highlight, which draws outside the view's bounds.
                ZStack(alignment: .topLeading) {
                    Text("Glucose", comment: "Title for predicted glucose chart on bolus screen")
                        .font(.subheadline)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(isInteractingWithChart ? 0 : 1)

                    predictedGlucoseChart
                        .padding(.horizontal, -4)
                        .padding(.top, UIFont.preferredFont(forTextStyle: .subheadline).lineHeight + 8) // Leave space for the 'Glucose' label + spacing
                        .clipped()
                }
                .frame(height: ceil(UIScreen.main.bounds.height / 4))
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var activeCarbsLabel: some View {
        if viewModel.activeCarbs != nil {
            LabeledQuantity(
                label: Text("Active Carbs", comment: "Title describing quantity of still-absorbing carbohydrates"),
                quantity: viewModel.activeCarbs!,
                unit: .gram()
            )
        }
    }

    @ViewBuilder
    private var activeInsulinLabel: some View {
        if viewModel.activeInsulin != nil {
            LabeledQuantity(
                label: Text("Active Insulin", comment: "Title describing quantity of still-absorbing insulin"),
                quantity: viewModel.activeInsulin!,
                unit: .internationalUnit(),
                maxFractionDigits: 2
            )
        }
    }

    private var predictedGlucoseChart: some View {
        PredictedGlucoseChartView(
            chartManager: viewModel.chartManager,
            glucoseUnit: viewModel.glucoseUnit,
            glucoseValues: viewModel.glucoseValues,
            predictedGlucoseValues: viewModel.predictedGlucoseValues,
            targetGlucoseSchedule: viewModel.targetGlucoseSchedule,
            preMealOverride: viewModel.preMealOverride,
            scheduleOverride: viewModel.scheduleOverride,
            dateInterval: viewModel.chartDateInterval,
            isInteractingWithChart: $isInteractingWithChart
        )
    }

    private var summarySection: some View {
        Section {
            VStack(spacing: 16) {
                Text("Bolus Summary", comment: "Title for card displaying carb entry and bolus recommendation")
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isManualGlucoseEntryEnabled {
                    manualGlucoseEntryRow
                } else if viewModel.potentialCarbEntry != nil {
                    potentialCarbEntryRow
                } else {
                    recommendedBolusRow
                }
            }
            .padding(.top, 8)

            if isManualGlucoseEntryEnabled && viewModel.potentialCarbEntry != nil {
                potentialCarbEntryRow
            }

            if isManualGlucoseEntryEnabled || viewModel.potentialCarbEntry != nil {
                recommendedBolusRow
            }

            bolusEntryRow
        }
    }

    private var glucoseFormatter: NumberFormatter {
        QuantityFormatter(for: viewModel.glucoseUnit).numberFormatter
    }

    private var glucosePlaceholder: HKQuantity {
        HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 0)
    }

    @ViewBuilder
    private var manualGlucoseEntryRow: some View {
        if isManualGlucoseEntryEnabled {
            HStack {
                Text("Manual BG Entry", comment: "Label for manual glucose entry row on bolus screen")
                Spacer()
                HStack(alignment: .firstTextBaseline) {
                    DismissibleKeyboardTextField(
                        text: typedManualGlucoseEntry,
                        placeholder: glucoseFormatter.string(from: glucosePlaceholder.doubleValue(for: viewModel.glucoseUnit)) ?? String(describing: glucosePlaceholder),
                        font: .heavy(.title1),
                        textAlignment: .right,
                        keyboardType: .decimalPad
                    )

                    Text(QuantityFormatter().string(from: viewModel.glucoseUnit))
                        .foregroundColor(Color(.secondaryLabelColor))
                }
            }
        }
    }

    private var typedManualGlucoseEntry: Binding<String> {
        Binding(
            get: { self.enteredManualGlucose },
            set: { newValue in
                if let doubleValue = self.glucoseFormatter.number(from: newValue)?.doubleValue {
                    self.viewModel.enteredManualGlucose = HKQuantity(unit: self.viewModel.glucoseUnit, doubleValue: doubleValue)
                } else {
                    self.viewModel.enteredManualGlucose = nil
                }

                self.enteredManualGlucose = newValue
            }
        )
    }

    @ViewBuilder
    private var potentialCarbEntryRow: some View {
        if viewModel.carbEntryAmountAndEmojiString != nil && viewModel.carbEntryDateAndAbsorptionTimeString != nil {
            HStack {
                Text("Carb Entry", comment: "Label for carb entry row on bolus screen")

                Text(viewModel.carbEntryAmountAndEmojiString!)
                    .foregroundColor(Color(.COBTintColor))
                    .modifier(LabelBackground())

                Spacer()

                Text(viewModel.carbEntryDateAndAbsorptionTimeString!)
                    .foregroundColor(Color(.secondaryLabelColor))
            }
        }
    }

    private static let doseAmountFormatter: NumberFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.setPreferredNumberFormatter(for: .internationalUnit())
        return quantityFormatter.numberFormatter
    }()

    private var recommendedBolusRow: some View {
        HStack {
            Text("Recommended Bolus", comment: "Label for recommended bolus row on bolus screen")
            Spacer()
            HStack(alignment: .firstTextBaseline) {
                Text(recommendedBolusString)
                    .font(.title)
                    .foregroundColor(viewModel.enteredBolus.doubleValue(for: .internationalUnit()) == 0 && viewModel.isBolusRecommended ? .accentColor : Color(.label))
                    .onTapGesture {
                        if self.viewModel.isBolusRecommended {
                            self.typedBolusEntry.wrappedValue = self.recommendedBolusString
                        }
                    }

                bolusUnitsLabel
            }
        }
    }

    private var recommendedBolusString: String {
        let amount = viewModel.recommendedBolus?.doubleValue(for: .internationalUnit()) ?? 0
        return Self.doseAmountFormatter.string(from: amount) ?? String(amount)
    }

    private var bolusEntryRow: some View {
        HStack {
            Text("Bolus", comment: "Label for bolus entry row on bolus screen")
            Spacer()
            HStack(alignment: .firstTextBaseline) {
                DismissibleKeyboardTextField(
                    text: typedBolusEntry,
                    placeholder: Self.doseAmountFormatter.string(from: 0.0)!,
                    font: .preferredFont(forTextStyle: .title1),
                    textColor: .systemBlue,
                    textAlignment: .right,
                    keyboardType: .decimalPad
                )
                
                bolusUnitsLabel
            }
        }
    }

    private var bolusUnitsLabel: some View {
        Text(QuantityFormatter().string(from: .internationalUnit()))
            .foregroundColor(Color(.secondaryLabelColor))
    }

    private var typedBolusEntry: Binding<String> {
        Binding(
            get: { self.enteredBolusAmount },
            set: { newValue in
                self.viewModel.enteredBolus = HKQuantity(unit: .internationalUnit(), doubleValue: Self.doseAmountFormatter.number(from: newValue)?.doubleValue ?? 0)
                self.enteredBolusAmount = newValue
            }
        )
    }

    private var actionArea: some View {
        VStack(spacing: 0) {
            if viewModel.activeNotice != nil {
                warning(for: viewModel.activeNotice!)
                    .padding()
                    .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
            }

            VStack(spacing: 10) {
                if viewModel.activeNotice == .staleGlucoseData {
                    enterManualGlucoseButton
                }

                primaryActionButton
            }
        }
        .padding(.bottom) // FIXME: unnecessary on iPhone 8 size devices
        .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
    }

    private func warning(for notice: BolusEntryViewModel.Notice) -> some View {
        switch notice {
        case .noBolusRecommended(suspendThreshold: let suspendThreshold):
            let suspendThresholdString = QuantityFormatter().string(from: suspendThreshold, for: viewModel.glucoseUnit) ?? String(describing: suspendThreshold)
            return WarningView(
                title: Text("No Bolus Recommended", comment: "Title for bolus screen notice when no bolus is recommended"),
                caption: Text("Your glucose is predicted to go below your suspend threshold, \(suspendThresholdString).", comment: "Caption for bolus screen notice when no bolus is recommended due to prediction dropping below suspend threshold")
            )
        case .staleGlucoseData:
            return WarningView(
                title: Text("No Recent Glucose Data", comment: "Title for bolus screen notice when glucose data is missing or stale"),
                caption: Text("Enter a manual glucose for a recommended bolus amount.", comment: "Caption for bolus screen notice when glucose data is missing or stale")
            )
        }
    }

    private var enterManualGlucoseButton: some View {
        Button(
            action: { self.isManualGlucoseEntryEnabled = true },
            label: { Text("Enter Manual BG") }
        )
        .buttonStyle(ActionButtonStyle(.primary))
        .padding(.horizontal)
    }

    private var primaryActionButton: some View {
        Button(
            action: {
                self.viewModel.saveCarbsAndDeliverBolus(onSuccess: self.dismiss)
            },
            label: {
                if viewModel.potentialCarbEntry != nil && viewModel.enteredBolus.doubleValue(for: .internationalUnit()) == 0 {
                    Text("Save without Bolusing")
                } else {
                    Text("Save and Deliver")
                }
            }
        )
        .buttonStyle(ActionButtonStyle(viewModel.activeNotice == .staleGlucoseData ? .secondary : .primary))
        .padding([.horizontal, .bottom])
        .disabled(viewModel.potentialCarbEntry == nil && viewModel.enteredBolus.doubleValue(for: .internationalUnit()) == 0)
    }

    private func alert(for alert: BolusEntryViewModel.Alert) -> SwiftUI.Alert {
        switch alert {
        case .recommendationChanged:
            return SwiftUI.Alert(
                title: Text("Bolus Recommendation Updated", comment: "Alert title for an updated bolus recommendation"),
                message: Text("The bolus recommendation has updated. Please reconfirm the bolus amount.", comment: "Alert message for an updated bolus recommendation")
            )
        case .maxBolusExceeded:
            guard let maximumBolusAmountString = viewModel.maximumBolusAmountString else {
                fatalError("Impossible to exceed max bolus without a configured max bolus")
            }
            return SwiftUI.Alert(
                title: Text("Exceeds Maximum Bolus", comment: "Alert title for a maximum bolus validation error"),
                message: Text("The maximum bolus amount is \(maximumBolusAmountString) U", comment: "Alert message for a maximum bolus validation error (1: max bolus value)")
            )
        case .noPumpManagerConfigured:
            return SwiftUI.Alert(
                title: Text("No Pump Configured", comment: "Alert title for a missing pump error"),
                message: Text("A pump must be configured before a bolus can be delivered.", comment: "Alert message for a missing pump error")
            )
        case .noMaxBolusConfigured:
            return SwiftUI.Alert(
                title: Text("No Maximum Bolus Configured", comment: "Alert title for a missing maximum bolus setting error"),
                message: Text("The maximum bolus setting must be configured before a bolus can be delivered.", comment: "Alert message for a missing maximum bolus setting error")
            )
        case .carbEntryPersistenceFailure:
            return SwiftUI.Alert(
                title: Text("Failed to Save Carb Entry", comment: "Alert title for a carb entry persistence error"),
                message: Text("An error occurred while trying to save your carb entry.", comment: "Alert message for a carb entry persistence error")
            )
        }
    }
}

struct LabeledQuantity: View {
    var label: Text
    var quantity: HKQuantity
    var unit: HKUnit
    var maxFractionDigits: Int?

    var body: some View {
        HStack(spacing: 4) {
            label
                .bold()
            valueText
                .foregroundColor(Color(.secondaryLabelColor))
        }
        .font(.subheadline)
        .modifier(LabelBackground())
    }

    var valueText: Text {
        let formatter = QuantityFormatter()
        formatter.setPreferredNumberFormatter(for: unit)

        if let maxFractionDigits = maxFractionDigits {
            formatter.numberFormatter.maximumFractionDigits = maxFractionDigits
        }

        guard let string = formatter.string(from: quantity, for: unit) else {
            assertionFailure("Unable to format \(quantity) \(unit)")
            return Text("")
        }

        return Text(string)
    }
}

struct LabelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(.systemGray6))
            )
    }
}

extension UIFont {
    static func heavy(_ textStyle: UIFont.TextStyle) -> UIFont {
        let descriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: textStyle)
            .addingAttributes([
                .traits: [
                    UIFontDescriptor.TraitKey.weight: UIFont.Weight.heavy
                ]
            ])

        return UIFont(descriptor: descriptor, size: 0)
    }
}
