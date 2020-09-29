//
//  SimpleBolusView.swift
//  LoopUITestApp
//
//  Created by Pete Schwamb on 9/23/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import HealthKit


struct SimpleBolusView: View, HorizontalSizeClassOverride {
    
    @State private var shouldBolusEntryBecomeFirstResponder = false
    @State private var isKeyboardVisible = false
    
    var displayMealEntry: Bool
    @ObservedObject var viewModel: SimpleBolusViewModel
    
    init(displayMealEntry: Bool, viewModel: SimpleBolusViewModel) {
        self.displayMealEntry = displayMealEntry
        self.viewModel = viewModel
    }
    
    var title: String {
        if displayMealEntry {
            return NSLocalizedString("Simple Meal Calculator", comment: "Title of simple bolus view when displaying meal entry")
        } else {
            return NSLocalizedString("Simple Bolus Calculator", comment: "Title of simple bolus view when not displaying meal entry")
        }
    }

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
                .navigationBarTitle(Text(self.title), displayMode: .inline)
                
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
            if displayMealEntry {
                carbEntryRow
            }
            glucoseEntryRow
            recommendedBolusRow
            bolusEntryRow
        }
    }
    
    private var carbEntryRow: some View {
        HStack {
            Text("Carbohydrates", comment: "Label for carbohydrates entry row on simple bolus screen")
            Spacer()
            HStack(alignment: .firstTextBaseline) {
                DismissibleKeyboardTextField(
                    text: $viewModel.enteredCarbAmount,
                    placeholder: viewModel.carbPlaceholder,
                    font: .preferredFont(forTextStyle: .title1),
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
                    text: $viewModel.enteredGlucoseAmount,
                    placeholder: "--",
                    font: .preferredFont(forTextStyle: .title1),
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
                Text(viewModel.recommendedBolus)
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
                    text: $viewModel.enteredBolusAmount,
                    placeholder: "",
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
    }
    
    private var glucoseUnitsLabel: some View {
        Text(QuantityFormatter().string(from: viewModel.glucoseUnit))
            .foregroundColor(Color(.secondaryLabel))
    }

    private var bolusUnitsLabel: some View {
        Text(QuantityFormatter().string(from: .internationalUnit()))
            .foregroundColor(Color(.secondaryLabel))
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
    static var viewModel: SimpleBolusViewModel = SimpleBolusViewModel(glucoseUnit: .milligramsPerDeciliter) { (input) in
            let (carbs, glucose) = input
            var recommendation: Double = 0
            if let carbs = carbs {
                recommendation += carbs.doubleValue(for: .gram()) / 10
            }
            if let glucose = glucose {
                recommendation = glucose.doubleValue(for: .milligramsPerDeciliter) - 105 / 80
            }
            return HKQuantity(unit: .internationalUnit(), doubleValue: max(0, recommendation))
        }
    
    static var previews: some View {
        NavigationView {
            SimpleBolusView(displayMealEntry: true, viewModel: viewModel)
        }
        .previewDevice("iPhone 11 Pro")
        //.colorScheme(.dark)
    }
}
