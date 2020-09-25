//
//  SimpleBolusCalculatorView.swift
//  LoopUITestApp
//
//  Created by Pete Schwamb on 9/23/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import HealthKit

struct SimpleBolusCalculatorView: View, HorizontalSizeClassOverride {
    
    @State private var enteredCarbAmount = ""
    @State private var enteredGlucose = ""
    @State private var enteredBolusAmount = ""
    @State private var shouldBolusEntryBecomeFirstResponder = false
    @State private var isKeyboardVisible = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                List() {
                    self.summarySection
                }
                // As of iOS 13, we can't programmatically scroll to the Bolus entry text field.  This ugly hack scoots the
                // list up instead, so the summarySection is visible and the keyboard shows when you tap "Enter Bolus".
                // Unfortunately, after entry, the field scoots back down and remains hidden.  So this is not a great solution.
                // TODO: Fix this in Xcode 12 when we're building for iOS 14.
                .padding(.top, self.shouldAutoScroll(basedOn: geometry) ? -200 : 0)
                .listStyle(GroupedListStyle())
                .environment(\.horizontalSizeClass, .regular)
                .navigationBarTitle("Simple Bolus Calculator", displayMode: .inline)
                
                self.actionArea
                    .frame(height: self.isKeyboardVisible ? 0 : nil)
                    .opacity(self.isKeyboardVisible ? 0 : 1)
            }
            .edgesIgnoringSafeArea(self.isKeyboardVisible ? [] : .bottom)
        }
    }
    
    private func shouldAutoScroll(basedOn geometry: GeometryProxy) -> Bool {
        // Taking a guess of 640 to cover iPhone SE, iPod Touch, and other smaller devices.
        // Devices such as the iPhone 11 Pro Max do not need to auto-scroll.
        shouldBolusEntryBecomeFirstResponder && geometry.size.height < 640
    }
    
    private var info: some View {
        HStack {
            Image("Open Loop")
            Text("When out of Closed Loop mode, the app uses a simplified bolus calculator like a typical pump.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Image(systemName: "info.circle").foregroundColor(.accentColor)
        }
        .padding([.top, .bottom])
    }
    
    private var summarySection: some View {
        Section(header: info) {
            carbEntryRow
            glucoseEntryRow
            recommendedBolusRow
            bolusEntryRow
        }
    }
    
    private static let doseAmountFormatter: NumberFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.setPreferredNumberFormatter(for: .internationalUnit())
        return quantityFormatter.numberFormatter
    }()
    
    private static let carbAmountFormatter: NumberFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.setPreferredNumberFormatter(for: .gram())
        return quantityFormatter.numberFormatter
    }()


    private var carbEntryRow: some View {
        HStack {
            Text("Carbohydrates", comment: "Label for carbohydrates entry row on simple bolus screen")
            Spacer()
            HStack(alignment: .firstTextBaseline) {
                DismissibleKeyboardTextField(
                    text: typedBolusEntry,
                    placeholder: Self.carbAmountFormatter.string(from: 0.0)!,
                    font: .preferredFont(forTextStyle: .title1),
                    textColor: .carbTintColor,
                    textAlignment: .right,
                    keyboardType: .decimalPad,
                    shouldBecomeFirstResponder: shouldBolusEntryBecomeFirstResponder
                )
                
                carbUnitsLabel
            }
        }
    }

    private var glucoseEntryRow: some View {
        HStack {
            Text("Current Glucose", comment: "Label for glucose entry row on simple bolus screen")
            Spacer()
            HStack(alignment: .firstTextBaseline) {
                DismissibleKeyboardTextField(
                    text: typedGlucose,
                    placeholder: "--",
                    font: .preferredFont(forTextStyle: .title1),
                    textColor: .loopAccent,
                    textAlignment: .right,
                    keyboardType: .decimalPad,
                    shouldBecomeFirstResponder: shouldBolusEntryBecomeFirstResponder
                )
                
                glucoseUnitsLabel
            }
        }
    }

    private var recommendedBolusRow: some View {
        HStack {
            Text("Recommended Bolus", comment: "Label for recommended bolus row on simple bolus screen")
            Spacer()
            HStack(alignment: .firstTextBaseline) {
                Text("3.0")
                    .font(.title)
                    .foregroundColor(Color(.label))
                bolusUnitsLabel
            }
        }
    }
    
    private var bolusEntryRow: some View {
        HStack {
            Text("Bolus", comment: "Label for bolus entry row on simple bolus screen")
            Spacer()
            HStack(alignment: .firstTextBaseline) {
                DismissibleKeyboardTextField(
                    text: typedBolusEntry,
                    placeholder: Self.doseAmountFormatter.string(from: 0.0)!,
                    font: .preferredFont(forTextStyle: .title1),
                    textColor: .loopAccent,
                    textAlignment: .right,
                    keyboardType: .decimalPad,
                    shouldBecomeFirstResponder: shouldBolusEntryBecomeFirstResponder
                )
                
                bolusUnitsLabel
            }
        }
    }

    private var carbUnitsLabel: some View {
        Text(QuantityFormatter().string(from: .gram()))
            .foregroundColor(Color(.systemGreen))
    }
    
    private var glucoseUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))

    private var glucoseUnitsLabel: some View {
        Text(QuantityFormatter().string(from: glucoseUnit))
            .foregroundColor(Color(.secondaryLabel))
    }

    private var bolusUnitsLabel: some View {
        Text(QuantityFormatter().string(from: .internationalUnit()))
            .foregroundColor(Color(.secondaryLabel))
    }



    private var typedCarbEntry: Binding<String> {
        Binding(
            get: { self.enteredCarbAmount },
            set: { newValue in
                print("New value = \(newValue)")
//                self.viewModel.enteredBolus = HKQuantity(unit: .internationalUnit(), doubleValue: Self.doseAmountFormatter.number(from: newValue)?.doubleValue ?? 0)
//                self.enteredBolusAmount = newValue
            }
        )
    }

    private var typedGlucose: Binding<String> {
        Binding(
            get: { self.enteredGlucose },
            set: { newValue in
                print("New value = \(newValue)")
//                self.viewModel.enteredBolus = HKQuantity(unit: .internationalUnit(), doubleValue: Self.doseAmountFormatter.number(from: newValue)?.doubleValue ?? 0)
//                self.enteredBolusAmount = newValue
            }
        )
    }

    private var typedBolusEntry: Binding<String> {
        Binding(
            get: { self.enteredBolusAmount },
            set: { newValue in
                print("New value = \(newValue)")
//                self.viewModel.enteredBolus = HKQuantity(unit: .internationalUnit(), doubleValue: Self.doseAmountFormatter.number(from: newValue)?.doubleValue ?? 0)
//                self.enteredBolusAmount = newValue
            }
        )
    }
    
    private var actionArea: some View {
        VStack(spacing: 0) {
            actionButton
        }
        .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
    }
    
    private var actionButton: some View {
        Button<Text>(
            action: {
                print("Action tapped")
            },
            label: {
                return Text("Save without Bolusing", comment: "Button text to save carbs and/or manual glucose entry without a bolus")
            }
        )
        .buttonStyle(ActionButtonStyle(.primary))
        .padding()
    }
}

struct SimpleBolusCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SimpleBolusCalculatorView()
        }
        .previewDevice("iPhone 11 Pro")
        //.colorScheme(.dark)
    }
}
