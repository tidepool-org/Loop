//
//  InsulinScaleAdjustView.swift
//  Loop
//
//  Created by Pete Schwamb on 3/10/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKit
import LoopKitUI

public struct InsulinScaleAdjustView: View {
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.guidanceColors) private var guidanceColors
    @Environment(\.settingsManager) private var settingsManager

    @State private var presentInfoView: Bool = false

    @Binding var insulinMultiplier: Double

    var insulinPercentage: Double {
        get { return (insulinMultiplier * 100).rounded() }
    }

    var basalRate: Double? {
        if let baseValue = settingsManager.settings.basalRateSchedule?.value(at: Date()) {
            return baseValue * insulinMultiplier
        } else {
            return nil
        }
    }
    var carbRatio: Double? {
        if let baseValue = settingsManager.settings.carbRatioSchedule?.value(at: Date()) {
            return baseValue / insulinMultiplier
        } else {
            return nil
        }
    }
    var isf: LoopQuantity? {
        if let baseQuantity = settingsManager.settings.insulinSensitivitySchedule?.quantity(at: Date()) {
            let value = baseQuantity.doubleValue(for: .milligramsPerDeciliter)
            let adjustedValue = value / insulinMultiplier
            return LoopQuantity(unit: .milligramsPerDeciliterPerInternationalUnit, doubleValue: adjustedValue)
        } else {
            return nil
        }
    }

    public var body: some View {
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
            .padding(.top, -5)


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
        .sheet(isPresented: $presentInfoView) {
            InsulinScaleInformationView()
        }
    }

    var valueColor: Color {
        switch Guardrail.presetInsulinNeeds.classification(for: .init(unit: .percent, doubleValue: insulinPercentage)) {
        case .withinRecommendedRange:
            return .insulin
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .minimum, .maximum:
                return guidanceColors.critical
            case .belowRecommended, .aboveRecommended:
                return guidanceColors.warning
            }
        }
    }

    private var adjustInsulinControls: some View {
        HStack(spacing: 24) {
            Button(action: {
                if insulinPercentage > 10 {
                    insulinMultiplier = (insulinPercentage - 5) / 100
                }
            }) {
                Text(Image(systemName: "minus.circle.fill").symbolRenderingMode(.hierarchical))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.insulin)
            }
            .buttonStyle(BorderlessButtonStyle())


            Text("\(Int(insulinPercentage))%")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(valueColor)

            Button(action: {
                if insulinPercentage < 200 {
                    insulinMultiplier = (insulinPercentage + 5) / 100
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
                        .fixedSize(horizontal: false, vertical: true)
                } else if (insulinPercentage > 100) {
                    Text("This adjustment will make your settings stronger.")
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No change to insulin settings.")
                }
            }

            exampleSettings

            // Footer Note
            Text("Note: These example values are based on your current settings. Values may be different when you enable the preset.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .multilineTextAlignment(.leading)
    }

    private var sensitivityUnit: LoopUnit {
        switch displayGlucosePreference.unit {
        case .milligramsPerDeciliter:
            return .milligramsPerDeciliterPerInternationalUnit
        case .millimolesPerLiter:
            return .millimolesPerLiterPerInternationalUnit
        default:
            fatalError()
        }
    }


    private var exampleSettings: some View {
        Group {
            if let basalRate = basalRate, let carbRatio = carbRatio, let isf = isf {
                HStack(spacing: 0) {
                    SettingAdjustmentPreview(
                        value: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: basalRate),
                        displayUnit: .internationalUnitsPerHour,
                        name: "Basal Rate",
                        highlighted: insulinPercentage != 100
                    )

                    Spacer()

                    SettingAdjustmentPreview(
                        value: LoopQuantity(unit: .gramsPerUnit, doubleValue: carbRatio),
                        displayUnit: .gramsPerUnit,
                        name: "Carb Ratio",
                        highlighted: insulinPercentage != 100
                    )

                    Spacer()

                    SettingAdjustmentPreview(
                        value: isf,
                        displayUnit: sensitivityUnit,
                        name: "ISF",
                        highlighted: insulinPercentage != 100
                    )
                }
            }
        }
    }
}
