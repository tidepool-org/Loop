//
//  ManualGlucoseEntryRow.swift
//  Loop
//
//  Created by Pete Schwamb on 12/8/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopAlgorithm
import LoopKit
import LoopKitUI
import Combine

struct ManualGlucoseEntryRow: View {
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference

    @State private var valueText = ""

    @Binding var quantity: LoopQuantity?

    var isFocused: FocusState<Bool>.Binding

    private var enteredGlucose: Binding<String> {
        Binding(
            get: { valueText },
            set: { value in
                valueText = value
                let newQuantity = displayGlucosePreference.formatter.numberFormatter.number(from: value).map {
                    LoopQuantity(unit: displayGlucosePreference.unit, doubleValue: $0.doubleValue)
                }
                if newQuantity != quantity {
                    quantity = newQuantity
                }
            }
        )
    }

    var body: some View {
        HStack {
            Text("Fingerstick Glucose", comment: "Label for manual glucose entry row on bolus screen")
            Spacer()

            HStack(alignment: .firstTextBaseline) {
                LengthLimitedTextField(
                    NSLocalizedString("– – –", comment: "No glucose value representation (3 dashes for mg/dL)"),
                    text: enteredGlucose,
                    maxLength: 4
                )
                .textFieldStyle(.plain)
                .font(.title.weight(.heavy))
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .inputField(focus: isFocused)
                .onChange(of: displayGlucosePreference.unit) { _, _ in
                    unitsChanged()
                }
                .accessibilityLabel(Text("Fingerstick Glucose"))
                .accessibilityIdentifier("textField_FingerstickGlucose")
                
                Text(displayGlucosePreference.formatter.localizedUnitStringWithPlurality())
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
        .initialFocus(isFocused)
    }

    func unitsChanged() {
        if let quantity = quantity {
            valueText = displayGlucosePreference.format(quantity, includeUnit: false)
        }
    }
}
