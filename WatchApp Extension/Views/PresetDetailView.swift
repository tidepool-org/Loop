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
    @Environment(LoopDataManager.self) var loopManager
    @Environment(\.glucoseDisplayUnit) private var glucoseDisplayUnit
    @Environment(\.dismiss) private var dismiss

    @State private var crownValue: CGFloat = 0 // Tracks Digital Crown rotation
    @State private var startingPreset: Bool = false
    private let threshold: CGFloat = 20 // Rotation threshold to trigger action
    private let maxProgress: CGFloat = 20 // Max progress for the bar

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

    var progress: CGFloat {
        if startingPreset {
            return 1
        } else {
            return min(crownValue, maxProgress)/threshold
        }
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
                    .fill(startingPreset ? Color.green : Color.blue)
                    .frame(width: progress * 150, height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .animation(.easeInOut(duration: 0.2), value: crownValue) // Smooth animation for progress
                    .animation(.easeOut(duration: 0.3), value: startingPreset) // Fast animation for trigger
            }

            // Status text
            Text(startingPreset ? "Starting Preset..." : "Turn Digital Crown to Start")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
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
        .onDisappear() {
            if let reminder = loopManager.pendingPresetReminder, reminder.presetIdentifier == preset.id {
                // If this was shown for confirming preset activation from a reminder notification, and we
                // are being dismissed, treat the dismissal as an acknowledgement
                loopManager.pendingPresetReminder = nil
                Task {
                    try await loopManager.acknowledgeAlert(alertIdentifier: reminder.alertIdentifier, managerIdentifier: reminder.managerIdentifier)
                }
            }
        }
        .onChange(of: crownValue) { (oldValue, newValue) in
            if newValue >= threshold && !startingPreset {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    startingPreset = true
                    Task {
                        do {
                            var alertIdentifier: String? = nil
                            // If we're starting the preset from a reminder alert, then set alert identifier to acknowledge the alert
                            if let reminder = loopManager.pendingPresetReminder, reminder.presetIdentifier == preset.id {
                                alertIdentifier = reminder.presetIdentifier
                            }
                            try await loopManager.activateOverride(preset.createOverride(), alertIdentifierToAcknowledge: alertIdentifier)
                            WKInterfaceDevice.current().play(.success)
                        } catch {
                            print("Error! Could not activate preset: \(error)")
                            WKInterfaceDevice.current().play(.failure)
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(false) // Ensure back button is visible
    }
}
