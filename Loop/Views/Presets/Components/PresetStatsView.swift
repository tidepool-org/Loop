//
//  PresetStatsView.swift
//  Loop
//
//  Created by Cameron Ingham on 12/11/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import LoopKitUI
import SwiftUI

struct PresetStatsView: View {
    enum TherapySettingsImpactDisplayState {
        case hide
        case show(TherapySettings.InsulinMultiplierImpact)
    }

    @Environment(\.guidanceColors) private var guidanceColors
    @Environment(\.settingsManager) private var settingsManager
    @Environment(\.temporaryPresetsManager) private var temporaryPresetsManager
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference
    
    let insulinMultiplier: Double?
    let correctionRange: ClosedRange<LoopQuantity>?
    let guardrail: Guardrail<LoopQuantity>?
    let therapySettingsImpactDisplayState: TherapySettingsImpactDisplayState
    let isScheduled: Bool
    let isActive: Bool

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }
    
    var overallInsulinView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overall Insulin")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilitySortPriority(2)

            let percent = numberFormatter.string(from: insulinMultiplier ?? 1)!
            Group { Text(percent).bold() + Text(" of scheduled") }
                .font(.subheadline)
                .accessibilitySortPriority(1)
        }
        .accessibilityElement(children: .contain)
    }

    func guidanceColor(for classification: SafetyClassification?) -> Color? {
        guard let classification else { return nil }

        switch classification {
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .aboveRecommended, .belowRecommended:
                return guidanceColors.warning
            case .maximum, .minimum:
                return guidanceColors.critical
            }
        case .withinRecommendedRange:
            return nil
        }
    }
    
    func annotatedRangeText(target: ClosedRange<LoopQuantity>) -> some View {
        let lowerColor = guardrail?.color(for: target.lowerBound, guidanceColors: guidanceColors) ?? .primary
        let upperColor = guardrail?.color(for: target.upperBound, guidanceColors: guidanceColors) ?? .primary

        let units = Text(" \(displayGlucosePreference.unit.localizedUnitString(in: .medium) ?? displayGlucosePreference.unit.unitString)")
            .foregroundStyle(upperColor)
        let lower = Text(displayGlucosePreference.format(target.lowerBound, includeUnit: false))
            .foregroundStyle(lowerColor)
            .bold()
        let upper = Text(displayGlucosePreference.format(target.upperBound, includeUnit: false))
            .foregroundStyle(upperColor)
            .bold()
        let warningSymbol = Text("\(Image(systemName: "exclamationmark.triangle.fill"))")

        let lowerClassification = guardrail?.classification(for: target.lowerBound) ?? .withinRecommendedRange
        let upperClassification = guardrail?.classification(for: target.upperBound) ?? .withinRecommendedRange

        var accessibilityId = "text_PresetCorrectionRange_"
        
        switch (lowerClassification, upperClassification) {
        case (.withinRecommendedRange, .withinRecommendedRange):
            accessibilityId += "WithinRange"
        case (.withinRecommendedRange, .outsideRecommendedRange):
            accessibilityId += "UpperWarning"
            accessibilityId += upperColor == .red ? "Red" : "Orange"
        case (.outsideRecommendedRange, .outsideRecommendedRange):
            accessibilityId += "LowerWarning"
            accessibilityId += lowerColor == .red ? "Red" : "Orange"
            accessibilityId += "UpperWarning"
            accessibilityId += upperColor == .red ? "Red" : "Orange"
        case (.outsideRecommendedRange, .withinRecommendedRange):
            accessibilityId += "LowerWarning"
            accessibilityId += lowerColor == .red ? "Red" : "Orange"
        }
        
        return Group {
            switch (lowerClassification, upperClassification) {
            case (.withinRecommendedRange, .withinRecommendedRange):
                lower + Text(" - ") + upper + units
            case (.withinRecommendedRange, .outsideRecommendedRange):
                lower + Text(" - ") + warningSymbol.foregroundStyle(upperColor) + upper + units
            case (.outsideRecommendedRange, .outsideRecommendedRange):
                warningSymbol.foregroundStyle(lowerColor) + lower + Text("-").foregroundStyle(lowerColor) + warningSymbol.foregroundStyle(upperColor) + upper + units
            case (.outsideRecommendedRange, .withinRecommendedRange):
                warningSymbol.foregroundStyle(lowerColor) + lower + Text("-") + upper + units
            }
        }.accessibilityIdentifier(accessibilityId)
    }

    var correctionRangeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Correction Range")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilitySortPriority(2)
            
            Group {
                if let target = correctionRange {
                    annotatedRangeText(target: target)
                } else if isActive, let therapySettingsCorrectionRange = settingsManager.therapySettings.glucoseTargetRangeSchedule?.quantityRange(at: Date()) {
                    annotatedRangeText(target: therapySettingsCorrectionRange)
                } else {
                    Text("Scheduled Range")
                        .bold()
                }
            }
            .font(.subheadline)
            .accessibilitySortPriority(1)
        }
        .accessibilityElement(children: .contain)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    overallInsulinView
                    Spacer()
                    correctionRangeView
                    if isScheduled, !isActive {
                        Spacer()
                        Text(Image(systemName: "alarm"))
                            .font(.footnote)
                            .foregroundColor(.carbs)
                            .accessibilityLabel(Text("Scheduled reminder"))
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    overallInsulinView
                    correctionRangeView
                }
            }
            
            if case let .show(insulinMultiplierImpact) = therapySettingsImpactDisplayState, (insulinMultiplier ?? 1) != 1, let basalRate = insulinMultiplierImpact.basalRate, let carbRatio = insulinMultiplierImpact.carbRatio, let isf = insulinMultiplierImpact.isf {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings Impact")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 0) {
                            SettingAdjustmentPreview(value: basalRate, displayUnit: .internationalUnitsPerHour, name: "Basal Rate", highlighted: false)
                            
                            Spacer()
                            
                            SettingAdjustmentPreview(value: carbRatio, name: "Carb Ratio", highlighted: false)
                        
                            Spacer()
                            
                            SettingAdjustmentPreview(value: isf, displayUnit: displayGlucosePreference.unit.unitDivided(by: .internationalUnit), name: "ISF", highlighted: false)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            SettingAdjustmentPreview(value: basalRate, displayUnit: .internationalUnitsPerHour, name: "Basal Rate", highlighted: false)
                            
                            SettingAdjustmentPreview(value: carbRatio, name: "Carb Ratio", highlighted: false)
                            
                            SettingAdjustmentPreview(value: isf, displayUnit: displayGlucosePreference.unit.unitDivided(by: .internationalUnit), name: "ISF", highlighted: false)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
