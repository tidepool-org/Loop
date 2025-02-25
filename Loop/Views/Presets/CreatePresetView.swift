//
//  CreatePresetView.swift
//  Loop
//
//  Created by Pete Schwamb on 2/15/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct CreatePresetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var insulinPercentage: Double = 85
    @State private var presentInfoView: Bool = false

    private let metrics = [
        ("Basal Rate", "0.75 U/hr"),
        ("Carb Ratio", "12 g"),
        ("ISF", "47 mg/dL")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // Header Section
                VStack(spacing: 16) {
                    HStack {
                        Text("Overall Insulin Needs")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .padding(.vertical)

                        Button(action: {
                            presentInfoView = true;
                        }) {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }

                    Text("Set your overall insulin needs")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Use the + and - buttons to set whether you need") +
                    Text(" more ").fontWeight(.bold) +
                    Text("or") +
                    Text(" less ").fontWeight(.bold) +
                    Text("insulin than usual.")

                    HStack(spacing: 24) {
                        Button(action: {
                            if insulinPercentage > 0 {
                                insulinPercentage -= 5
                            }
                        }) {
                            Text(Image(systemName: "minus.circle.fill").symbolRenderingMode(.hierarchical))
                                .font(.system(size: 40))
                                .foregroundColor(.insulin)
                        }
                        .buttonStyle(BorderlessButtonStyle())


                        Text("\(Int(insulinPercentage))%")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundColor(.insulin)

                        Button(action: {
                            if insulinPercentage < 200 {
                                insulinPercentage += 5
                            }
                        }) {
                            Text(Image(systemName: "plus.circle.fill").symbolRenderingMode(.hierarchical))
                                .font(.system(size: 40))
                                .foregroundColor(.insulin)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }

                    Text("Settings Impact")
                        .font(.headline)

                    Text("This adjustment will make your settings weaker.")
                        .foregroundColor(.secondary)

                    HStack(spacing: 32) {
                        ForEach(metrics, id: \.0) { metric in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(metric.1)
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                Text(metric.0)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Footer Note
                    Text("Note: These example values are based on your current settings. Values may be different when you enable the preset.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Spacer()
                }
                .font(.body)
                .multilineTextAlignment(.center)
            }

            actionArea
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Create a preset")
        .edgesIgnoringSafeArea(.bottom)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private var actionArea: some View {
        VStack(spacing: 0) {
            actionButton
        }
        .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
    }

    private var actionButton: some View {
        Button("Continue") {
            //range = editedRange
           // dismiss()
        }
        .buttonStyle(ActionButtonStyle(.primary))
        .padding()
    }

}

#Preview {
    CreatePresetView()
}
