//
//  CreatePresetView.swift
//  Loop
//
//  Created by Pete Schwamb on 2/15/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKitUI
import LoopKit


enum CreatePresetPage: Hashable {
    case correctionRange
    case name
    case summary
}

struct SettingAdjustmentPreview: View {
    let value: LoopQuantity
    let displayUnit: LoopUnit
    let name: String
    private let formatter: QuantityFormatter
    private let highlighted: Bool

    init(value: LoopQuantity, displayUnit: LoopUnit, name: String, highlighted: Bool = false) {
        self.value = value
        self.displayUnit = displayUnit
        self.name = name
        self.formatter = QuantityFormatter(for: displayUnit)
        self.highlighted = highlighted
    }

    var valueRow: some View {
        Text(formatter.string(from: value, includeUnit: false) ?? "NA")
            .bold() + Text(" ") +
        Text(displayUnit.shortLocalizedUnitString())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if highlighted {
                valueRow.foregroundColor(.insulin)
            } else {
                valueRow
            }
            Text(name)
        }
    }
}

struct CreatePresetView: View {
    @Environment(\.therapySettings) private var therapySettings
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference

    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()
    @State private var preset = NewCustomPreset()
    @State private var presentInfoView: Bool = false
    @State private var navigateToRangeEdit: Bool = false

    var basalRate: Double? {
        if let baseValue = therapySettings.basalRateSchedule?.value(at: Date()) {
            return baseValue * preset.insulinMultiplier
        } else {
            return nil
        }
    }
    var carbRatio: Double? {
        if let baseValue = therapySettings.carbRatioSchedule?.value(at: Date()) {
            return baseValue / preset.insulinMultiplier
        } else {
            return nil
        }
    }
    var isf: LoopQuantity? {
        if let baseQuantity = therapySettings.insulinSensitivitySchedule?.quantity(at: Date()) {
            let value = baseQuantity.doubleValue(for: .milligramsPerDeciliter)
            let adjustedValue = value / preset.insulinMultiplier
            return LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: adjustedValue)
        } else {
            return nil
        }
    }

    var insulinPercentage: Double {
        get { return (preset.insulinMultiplier * 100).rounded() }
    }

    var scheduledRange: ClosedRange<LoopQuantity>? {
        therapySettings.glucoseTargetRangeSchedule?.quantityRange(at: Date())
    }

    var body: some View {
        NavigationStack(path: $path) {
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

                        adjustInsulinControls

                        Divider()

                        settingsImpact

                    }
                    .multilineTextAlignment(.center)
                }

                actionArea
            }
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $presentInfoView) {
                InsulinScaleInformationView()
            }
            .navigationDestination(for: CreatePresetPage.self) { page in
                switch page {
                case .correctionRange:
                    Group {
                        if let scheduledRange {
                            NewPresetRangeEdit(
                                preset: $preset,
                                path: $path,
                                guardrail: Guardrail.correctionRange,
                                scheduledRange: scheduledRange
                            )
                        }
                    }
                case .summary:
                    Text("Summary view not yet implemented")
                case .name:
                    Text("Name view not yet implemented")
                }
            }
            .navigationTitle("Create a preset")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }


    private var adjustInsulinControls: some View {
        HStack(spacing: 24) {
            Button(action: {
                if insulinPercentage > 10 {
                    preset.insulinMultiplier = (insulinPercentage - 5) / 100
                }
            }) {
                Text(Image(systemName: "minus.circle.fill").symbolRenderingMode(.hierarchical))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.insulin)
            }
            .buttonStyle(BorderlessButtonStyle())


            Text("\(Int(insulinPercentage))%")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.insulin)

            Button(action: {
                if insulinPercentage < 200 {
                    preset.insulinMultiplier = (insulinPercentage + 5) / 100
                }
            }) {
                Text(Image(systemName: "plus.circle.fill").symbolRenderingMode(.hierarchical))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.insulin)
            }
            .buttonStyle(BorderlessButtonStyle())
        }

    }

    private var settingsImpact: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings Impact")
                    .font(.headline)

                if insulinPercentage < 100 {
                    Text("This adjustment will make your settings weaker.")
                } else if (insulinPercentage > 100) {
                    Text("This adjustment will make your settings stronger.")
                } else {
                    Text("No change to insulin settings.")
                }
            }

            exampleSettings

            // Footer Note
            Text("Note: These example values are based on your current settings. Values may be different when you enable the preset.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .font(.system(size: 15))
        .multilineTextAlignment(.leading)
    }

    private var exampleSettings: some View {
        Group {
            if let basalRate = basalRate, let carbRatio = carbRatio, let isf = isf {
                HStack(spacing: 32) {
                    SettingAdjustmentPreview(
                        value: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: basalRate),
                        displayUnit: .internationalUnitsPerHour,
                        name: "Basal Rate",
                        highlighted: insulinPercentage != 100
                    )
                    .frame(maxWidth: .infinity)

                    SettingAdjustmentPreview(
                        value: LoopQuantity(unit: .gram, doubleValue: carbRatio),
                        displayUnit: .gram,
                        name: "Carb Ratio",
                        highlighted: insulinPercentage != 100
                    )
                    .frame(maxWidth: .infinity)

                    SettingAdjustmentPreview(
                        value: isf,
                        displayUnit: displayGlucosePreference.unit,
                        name: "ISF",
                        highlighted: insulinPercentage != 100
                    )
                    .frame(maxWidth: .infinity)
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
            path.append(CreatePresetPage.correctionRange)
        }
        .buttonStyle(ActionButtonStyle(.primary))
        .padding()
    }

}

#Preview {
    CreatePresetView()
}
