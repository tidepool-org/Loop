//
//  ActivePresetView.swift
//  Loop
//
//  Created by Pete Schwamb on 9/10/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopCore

struct ActiveOverrideView: View {
    @Environment(LoopDataManager.self) var loopManager
    @Environment(\.glucoseDisplayUnit) private var glucoseDisplayUnit

    @State private var crownValue: CGFloat = 0 // Tracks Digital Crown rotation
    @State private var endingPreset: Bool = false
    @State private var lastInteractionTime: Date? // Tracks last crown interaction

    private let threshold: CGFloat = 20 // Rotation threshold to trigger action
    private let maxProgress: CGFloat = 20 // Max progress for the bar
    private let resetDelay: TimeInterval = 0.25 // pause for reset

    let override: TemporaryScheduleOverride
    var preset: SelectablePreset {
        return override.createPreset()
    }

    var title: some View {
        HStack(spacing: 6) {
            if let icon = preset.icon, !icon.isEmpty {
                PresetSymbolView(icon)
            }
            Text(preset.name)
                .font(.system(size: 19))
        }
    }

    var duration: Text {
        if override.isActive() {
            if override.context == .preMeal {
                return Text(NSLocalizedString("on until carbs added", comment: "The format for the description of a premeal preset end date"))
            } else {
                switch override.duration {
                case .finite:
                    let endTimeText = DateFormatter.localizedString(from: override.activeInterval.end, dateStyle: .none, timeStyle: .short)
                    return Text(String(format: NSLocalizedString("on until %@", comment: "The format for the description of a finite custom preset end date"), endTimeText))
                case .indefinite:
                    return Text(NSLocalizedString("on until turned off", comment: "The format for the description of an indefinite custom preset end date"))
                }
            }
        } else {
            let startTimeText = DateFormatter.localizedString(from: override.startDate, dateStyle: .none, timeStyle: .short)
            return Text(String(format: NSLocalizedString("starting at %@", comment: "The format for the description of a custom preset start date"), startTimeText))
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
        Group { Text(Image(systemName: "timer")) + duration }
            .font(.footnote)
            .foregroundColor(.presets)
    }

    var descriptionText: Text {
        let percent = numberFormatter.string(from: override.settings.insulinNeedsScaleFactor ?? 1)!
        var text = Text(percent).bold()

        if let correctionRange = override.settings.targetRange {
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
        if endingPreset {
            return 1
        } else {
            return min(crownValue, maxProgress)/threshold
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            title
            presetDuration
            descriptionText
                .padding(.top, 8)
                .padding(.bottom, 10)

            Spacer()

            ZStack(alignment: .center) {
                if progress == 0 {
                    Text(endingPreset ? "Ending Preset..." : "Turn Digital Crown to End")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    CircularProgressWithCheckmark(progress: progress, isComplete: endingPreset)
                                    .animation(.easeInOut(duration: 0.2), value: crownValue) // Smooth animation for progress
                                    .animation(.easeOut(duration: 0.3), value: endingPreset) // Fast animation for completion
                }
            }
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
            lastInteractionTime = Date()

            Task {
                try? await Task.sleep(nanoseconds: UInt64(resetDelay * 1_000_000_000)) // Wait for 1 second
                if let lastTime = lastInteractionTime, Date().timeIntervalSince(lastTime) >= resetDelay && !endingPreset {
                    withAnimation {
                        crownValue = 0 // Reset progress
                    }
                }
            }

            if newValue >= threshold && !endingPreset {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    endingPreset = true
                    Task {
                        do {
                            try await loopManager.clearOverride()
                            WKInterfaceDevice.current().play(.directionDown)
                        } catch {
                            WKInterfaceDevice.current().play(.failure)
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(false) // Ensure back button is visible
    }
}
