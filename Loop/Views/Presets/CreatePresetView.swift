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
    case nameAndSchedule
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
        if displayUnit == .internationalUnitsPerHour {
            // Basal rates get special treatment here. Loop's default max for basal rate is 3 digits,
            // to support pumps that support that. The value shown here does not represent an actual
            // set basal rate, but rather a value computed by loop, used in computing insulin effects,
            // and is somewhat independent of pump supported rates. 2 digits is generally enough
            // precision here.
            self.formatter.numberFormatter.maximumFractionDigits = 2
        }
        self.highlighted = highlighted
    }

    var valueRow: some View {
        (Text(formatter.string(from: value, includeUnit: false) ?? "NA")
            .bold() + Text(" ") +
        Text(displayUnit.shortLocalizedUnitString()))
        .fixedSize(horizontal: false, vertical: true)
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
    @Environment(\.settingsManager) private var settingsManager
    @Environment(\.temporaryPresetsManager) private var temporaryPresetsManager
    @Environment(\.dismiss) private var dismiss

    @State private var path = NavigationPath()
    @State private var preset = NewCustomPreset()
    @State private var navigateToRangeEdit: Bool = false

    var scheduledRange: ClosedRange<LoopQuantity>? {
        settingsManager.settings.glucoseTargetRangeSchedule?.quantityRange(at: Date())
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Form {
                    InsulinScaleAdjustView(insulinMultiplier: $preset.insulinMultiplier)
                }

                actionArea
            }
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: CreatePresetPage.self) { page in
                switch page {
                case .correctionRange:
                    Group {
                        if let scheduledRange {
                            NewPresetRangeEdit(
                                preset: $preset,
                                path: $path,
                                guardrail: Guardrail.correctionRange,
                                scheduledRange: scheduledRange,
                                onCancel: { dismiss() }
                            )
                        }
                    }
                case .nameAndSchedule:
                    CreatePresetNameAndScheduledEdit(preset: $preset, path: $path, onCancel: { dismiss() })
                case .summary:
                    if let scheduledRange {
                        ReviewNewPresetView(
                            preset: $preset,
                            path: $path,
                            scheduledRange: scheduledRange,
                            onCancel: { dismiss() },
                            onComplete: { startPreset in
                                dismiss()
                                if let temporaryScheduleOverride = preset.temporaryScheduleOverride {
                                    if preset.savePreset, case .preset(let preset) = temporaryScheduleOverride.context {
                                        settingsManager.createPreset(preset)
                                    }
                                    if startPreset {
                                        temporaryPresetsManager.scheduleOverride = temporaryScheduleOverride
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Create a Preset")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
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
