//
//  EditPressRangeView.swift
//  Loop
//
//  Created by Pete Schwamb on 12/17/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//
import SwiftUI
import LoopAlgorithm
import LoopKit
import LoopKitUI

struct EditPresetRangeView: View {
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.dismiss) private var dismiss

    @Binding var range: ClosedRange<LoopQuantity>?
    var guardrail: Guardrail<LoopQuantity>
    private var scheduledRange: ClosedRange<LoopQuantity>

    private let availableRanges = stride(from: 65, through: 105, by: 5).map { String($0) }

    var lowerBoundStr: String { displayGlucosePreference.format((range ?? scheduledRange).lowerBound, includeUnit: false) }
    var upperBoundStr: String { displayGlucosePreference.format((range ?? scheduledRange).upperBound, includeUnit: false) }

    var body: some View {
        List {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Correction Range")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        Image(systemName: "info.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.accentColor)
                            .frame(width: UIFontMetrics.default.scaledValue(for: 14), height: UIFontMetrics.default.scaledValue(for: 14))
                    }
                    .padding(.top, 10)


                    Text("Set your correction range")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                    Text("To reduce the risk of highs or lows, you may want to set an adjusted range if you think your glucose will vary more than usual.")
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 0) {
                    Text("Adjusted Range")

                    Text("\(lowerBoundStr)-\(upperBoundStr)")
                        .font(.system(size: 48, weight: .bold   ))
                        .foregroundColor(.accentColor)

                    Text("mg/dL")
                        .foregroundColor(.secondary)
                }

                Divider()

                GlucoseRangePicker(range: Binding(
                    get: {}
}
                    set: {}),
                    unit: displayGlucosePreference.unit,
                    minValue: nil,
                    guardrail: guardrail)
                    .padding(.vertical, -20)

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.accentColor)

                    (Text("To help avoid lows, set a range ")
                     + Text("higher")
                        .italic()
                        .bold()
                     + Text(" than your typical correction range."))
                    .font(.system(size: 14))
                }
                .padding()
                .overlay( /// apply a rounded border
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.gray, lineWidth: 1)
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Edit Preset")
    }
}
