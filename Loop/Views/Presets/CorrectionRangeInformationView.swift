//
//  InsulinScaleInformationView.swift
//  Loop
//
//  Created by Pete Schwamb on 2/25/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


import SwiftUI

struct CorrectionRangeInformationView: View {
    @State private var insulinPercentage: Double = 100
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            VStack {
                Button("Close") {
                    dismiss()
                }
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()
            }
            .background(Color(.systemBackground))

            // Header
            VStack(alignment: .leading) {
                Text("Correction Range")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.vertical)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .background(Color(.systemBackground))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Description Text
                    (Text("Correction range is a ") + Text("safety").fontWeight(.semibold) + Text(" setting. Adjusting it can help reduce the risk of low glucose if you expect unusual fluctuations."))
                        .padding(.top)
                    Text("Set the glucose value (or values) you want Tidepool Loop to aim for in adjusting your basal insulin.")
                    Text("You do not have to set a new correction range for each preset, but before deciding to adjust your correction range, ") +
                    Text("ask yourself, am I more likely to go high or low during this event?")
                        .fontWeight(.semibold)

                    // Tip section
                    CorrectionRangeTipSection()
                }
                .padding()
            }
        }
    }
}

struct CorrectionRangeTipSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.blue)

                Text("Tip")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 4)

            Text("To help avoid lows, set a range higher than your typical correction range.")
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CorrectionRangeInformationView_Previews: PreviewProvider {
    static var previews: some View {
        CorrectionRangeInformationView()
    }
}
