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
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference
    
    let insulinSensitivityMultiplier: Double?
    let correctionRange: ClosedRange<LoopQuantity>?
    let guardrail: Guardrail<LoopQuantity>?
    let therapySettingsImpactDisplayState: TherapySettingsImpactDisplayState
    
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

            let percent = numberFormatter.string(from: 1.0/(insulinSensitivityMultiplier ?? 1))!
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
    
    @ViewBuilder
    func basalRateView(basalRateValue: String, condensed: Bool) -> some View {
        let label = Text("Basal Rate").font(.subheadline)
        let value = Group {
            Text(basalRateValue).bold() +
            Text(" \(LoopUnit.internationalUnitsPerHour.unitString)")
        }.font(.subheadline)
        
        if condensed {
            HStack {
                label + Text(": ")
                value
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                value
                label
            }
        }
    }
    
    @ViewBuilder
    func carbRatioView(carbRatioValue: String, condensed: Bool) -> some View {
        let label = Text("Carb Ratio").font(.subheadline)
        let value = Group {
            Text(carbRatioValue).bold() +
            Text(" \(LoopUnit.gram.unitString)")
        }.font(.subheadline)
        
        if condensed {
            HStack {
                label + Text(": ")
                value
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                value
                label
            }
        }
    }
    
    @ViewBuilder
    func isfView(isfValue: String, condensed: Bool) -> some View {
        let label = Text("ISF").font(.subheadline)
        let value = Group {
            Text(isfValue).bold() +
            Text(" \(displayGlucosePreference.unit.unitString)")
        }.font(.subheadline)
        
        if condensed {
            HStack {
                label + Text(": ")
                value
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                value
                label
            }
        }
    }
    
    private let basalRateFormatter = QuantityFormatter(for: .internationalUnitsPerHour)
    private let carbRatioFormatter = QuantityFormatter(for: .gram)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    overallInsulinView
                    Spacer()
                    correctionRangeView
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    overallInsulinView
                    correctionRangeView
                }
            }
            
            if case let .show(insulinMultiplierImpact) = therapySettingsImpactDisplayState, (insulinSensitivityMultiplier ?? 1) != 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings Impact")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 0) {
                            if let basalRate = insulinMultiplierImpact.basalRate, let basalRateValue = basalRateFormatter.string(from: basalRate, includeUnit: false) {
                                basalRateView(basalRateValue: basalRateValue, condensed: false)
                                Spacer()
                            }
                            
                            if let carbRatio = insulinMultiplierImpact.carbRatio, let carbRatioValue = carbRatioFormatter.string(from: carbRatio, includeUnit: false) {
                                carbRatioView(carbRatioValue: carbRatioValue, condensed: false)
                                Spacer()
                            }
                            
                            if let isf = insulinMultiplierImpact.isf, let isfValue = displayGlucosePreference.formatter.string(from: isf, includeUnit: false) {
                                isfView(isfValue: isfValue, condensed: false)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if let basalRate = insulinMultiplierImpact.basalRate, let basalRateValue = basalRateFormatter.string(from: basalRate, includeUnit: false) {
                                basalRateView(basalRateValue: basalRateValue, condensed: true)
                            }
                            
                            if let carbRatio = insulinMultiplierImpact.carbRatio, let carbRatioValue = carbRatioFormatter.string(from: carbRatio, includeUnit: false)  {
                                carbRatioView(carbRatioValue: carbRatioValue, condensed: true)
                            }
                            
                            if let isf = insulinMultiplierImpact.isf, let isfValue = displayGlucosePreference.formatter.string(from: isf, includeUnit: false) {
                                isfView(isfValue: isfValue, condensed: true)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
