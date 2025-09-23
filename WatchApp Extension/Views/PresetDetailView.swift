//
//  PresetDetailView.swift
//  Loop
//
//  Created by Pete Schwamb on 9/9/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopCore

struct PresetDetailView: View {
    @Environment(\.glucoseDisplayUnit) private var glucoseDisplayUnit

    let preset: SelectablePreset

    var presetTitle: some View {
        HStack(spacing: 6) {
            Text(preset.name)
                .font(.title3)
                .accessibilityIdentifier("text_Preset\(preset.name)")
        }
    }

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }

    private var glucoseFormatter: QuantityFormatter {
        return QuantityFormatter(for: glucoseDisplayUnit)
    }

    var presetDuration: some View {
        Group { Text(Image(systemName: "timer")) + Text(" \(preset.duration.localizedTitle)") }
            .font(.footnote)
            .foregroundColor(.secondary)
            .accessibilityLabel(Text(preset.duration.accessibilityLabel))
    }

    var descriptionText: Text {
        let percent = numberFormatter.string(from: preset.insulinNeedsScaleFactor)!
        var text = Text(percent).bold()

        if let correctionRange = preset.correctionRange {
            text = text + Text(" • ")
            text = text + (Text(glucoseFormatter.string(from: correctionRange.lowerBound, includeUnit: false)!) +
                           Text("-") +
                           Text(glucoseFormatter.string(from: correctionRange.upperBound, includeUnit: false)!)).bold()
            text = text + Text(" " + glucoseDisplayUnit.localizedShortUnitString)
                .foregroundStyle(.secondary)
        }
        return text
    }

    var body: some View {
        VStack(spacing: 4) {
            presetTitle
            presetDuration
            descriptionText
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
    }
}
