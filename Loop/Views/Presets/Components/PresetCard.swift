//
//  PresetCard.swift
//  Loop
//
//  Created by Cameron Ingham on 10/24/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKitUI
import SwiftUI

struct PresetCard<Icon: View>: View {
    
    enum DurationType {
        case untilCarbsEntered
        case duration(TimeInterval)
        
        var localizedTitle: String {
            switch self {
            case .untilCarbsEntered:
                return NSLocalizedString("until carbs added", comment: "Preset card carb entry duration")
            case .duration(let duration):
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute]
                formatter.unitsStyle = .short
                return formatter.string(from: duration) ?? ""
            }
        }
        
        var accessibilityLabel: String {
            switch self {
            case .untilCarbsEntered:
                return NSLocalizedString("Active until carbs are added", comment: "Presets card carb entry duration accessibility label")
            case .duration(let duration):
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute]
                formatter.unitsStyle = .spellOut
                return NSLocalizedString("Active for \(formatter.string(from: duration) ?? "")", comment: "Presets card time duration accessibility label")
            }
        }
    }
    
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference
    
    let icon: Icon
    let presetName: String
    let duration: DurationType
    let percentOfScheduled: Double
    let correctionRange: (lower: HKQuantity, upper: HKQuantity)
    
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }
    
    var presetTitle: some View {
        HStack(spacing: 4) {
            icon
                .aspectRatio(contentMode: .fit)
                .frame(width: UIFontMetrics.default.scaledValue(for: 20), height: UIFontMetrics.default.scaledValue(for: 20))
            
            Text(presetName)
                .fontWeight(.semibold)
        }
    }
    
    var presetDuration: some View {
        Group { Text(Image(systemName: "timer")) + Text(" \(duration.localizedTitle)") }
            .font(.footnote)
            .foregroundColor(.secondary)
            .accessibilityLabel(Text(duration.accessibilityLabel))
    }
    
    var overallInsulinView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overall Insulin")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilitySortPriority(2)
            
            if let percent = numberFormatter.string(from: percentOfScheduled) {
                Group { Text(percent).bold() + Text(" of scheduled") }
                    .font(.subheadline)
                    .accessibilitySortPriority(1)
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    var correctionRangeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Correction Range")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilitySortPriority(2)
            
            Group { Text(displayGlucosePreference.format(lowerQuantity: correctionRange.lower, higherQuantity: correctionRange.upper, includeUnit: false)).bold() + Text(" \(displayGlucosePreference.unit.localizedUnitString(in: .medium) ?? displayGlucosePreference.unit.unitString)") }
                .font(.subheadline)
                .accessibilitySortPriority(1)
        }
        .accessibilityElement(children: .contain)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    presetTitle
                    
                    Spacer()
                    
                    presetDuration
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    presetTitle
                    
                    presetDuration
                }
            }
            
            Divider()
                .padding(.horizontal, -10)
            
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
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8)
            .stroke(Color(UIColor.secondarySystemBackground), lineWidth: 1)
            .frame(maxWidth: .infinity))
    }
}
