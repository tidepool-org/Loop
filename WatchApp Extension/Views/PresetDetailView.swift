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

    @State private var crownValue: CGFloat = 0 // Tracks Digital Crown rotation
    @State private var isActionTriggered: Bool = false // Tracks if action is triggered
    private let threshold: CGFloat = 20 // Rotation threshold to trigger action
    private let maxProgress: CGFloat = 20 // Max progress for the bar

    let preset: SelectablePreset

    var presetTitle: some View {
        HStack(spacing: 6) {
            Text(preset.name)
                .font(.system(size: 19))
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

            // Progress bar
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                Rectangle()
                    .fill(isActionTriggered ? Color.green : Color.blue)
                    .frame(width: min(crownValue, maxProgress)/threshold * 150, height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .animation(.easeInOut(duration: 0.2), value: crownValue) // Smooth animation for progress
                    .animation(.easeOut(duration: 0.3), value: isActionTriggered) // Fast animation for trigger
            }

            // Status text
            Text(isActionTriggered ? "Starting Preset..." : "Turn Digital Crown to Start")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundColor(isActionTriggered ? .green : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .focusable() // Required for Digital Crown interaction
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: threshold,
            by: 1,
            sensitivity: .medium,
            isContinuous: false
        )
        .onChange(of: crownValue) { (oldValue, newValue) in
            // Trigger action when threshold is reached
            if newValue >= threshold && !isActionTriggered {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    isActionTriggered = true
                    // Perform your action here
                    print("Action triggered!")
                }
            }
        }
        .navigationTitle("Preset Details")
        .navigationBarBackButtonHidden(false) // Ensure back button is visible
    }
}
