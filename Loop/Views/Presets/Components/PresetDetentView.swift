//
//  PresetDetentView.swift
//  Loop
//
//  Created by Cameron Ingham on 12/11/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import SwiftUI

struct PresetDetentView: View {

    enum Operation {
        case start
        case end
    }
    
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.colorPalette) private var colorPalette
    @Environment(\.settingsManager) private var settingsManager
    @Environment(\.temporaryPresetsManager) private var temporaryPresetsManager
    @Environment(\.dismiss) private var dismiss
    
    let preset: SelectablePreset
    let didTapEdit: () -> Void

    var operation: Operation {
        if temporaryPresetsManager.activeOverride?.presetId == preset.id {
            return .end
        } else {
            return .start
        }
    }
    
    @ViewBuilder
    private var subtitle: some View {
        Group {
            switch operation {
            case .start:
                HStack {
                    if preset.isScheduled {
                        Text(Image(systemName: "alarm"))
                            .font(.footnote)
                            .foregroundColor(.carbs)
                            .accessibilityLabel(Text("Scheduled reminder"))
                    }
                    Text("Duration: \(preset.duration.localizedTitle)")
                }
            case .end:
                if let activeOverride = temporaryPresetsManager.activeOverride {
                    if activeOverride.presetId == preset.id {
                        switch activeOverride.duration {
                        case .finite:
                            let endTimeText = DateFormatter.localizedString(from: activeOverride.activeInterval.end, dateStyle: .none, timeStyle: .short)
                            Text(String(format: NSLocalizedString("on until %@", comment: "The format for the description of a custom preset end date"), endTimeText))
                                .accessibilityIdentifier("text_PresetActionSheetActiveOn")
                        case .indefinite:
                            EmptyView()
                        }
                    } else {
                        let startTimeText = DateFormatter.localizedString(from: activeOverride.startDate, dateStyle: .none, timeStyle: .short)
                        Text(String(format: NSLocalizedString("starting at %@", comment: "The format for the description of a custom preset start date"), startTimeText))
                    }
                }
            }
        }
        .font(.subheadline)
    }
    
    @ViewBuilder
    var actionArea: some View {
        VStack(spacing: 12) {
            switch operation {
            case .start:
                Button("Start Preset") {
                    temporaryPresetsManager.startPreset(preset)
                    dismiss()
                }
                .buttonStyle(ActionButtonStyle())
                .disabled(temporaryPresetsManager.activeOverride != nil && preset.id != temporaryPresetsManager.activeOverride?.presetId)
                .accessibilityIdentifier("button_startPreset")
            case .end:
                Button("End Preset") {
                    temporaryPresetsManager.endPreset()
                    dismiss()
                }
                .buttonStyle(ActionButtonStyle(.destructive))
                .accessibilityIdentifier("button_endPreset")
                
                if preset.duration != .untilCarbsEntered {
                    NavigationLink("Adjust Preset Duration") {
                        EditPresetDurationView()
                    }
                    .buttonStyle(ActionButtonStyle(.tertiary))
                    .accessibilityIdentifier("button_adjustPresetDuration")
                }
            }
            
            Button("Close") {
                dismiss()
            }
            .tint(.accentColor)
            .fontWeight(.semibold)
            .accessibilityIdentifier("button_close")
        }
    }
    
    @State var sheetContentHeight: Double = 0

    var settingsImpact: TherapySettings.InsulinMultiplierImpact {
        settingsManager.therapySettings.impact(for: preset.insulinNeedsScaleFactor)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        preset.title(font: .title2, iconSize: 20, colorPalette: colorPalette)
                        subtitle
                    }
                    
                    if operation == .start {
                        Button {
                            didTapEdit()
                        } label: {
                            Group {
                                Text(Image(systemName: "pencil")) + Text(" ") + Text("Edit Preset")
                            }
                            .font(.subheadline)
                        }
                        .tint(.accentColor)
                        .padding(.bottom, -8)
                        .accessibilityIdentifier("button_EditPreset")
                    }
                }
                
                Divider()
                
                PresetStatsView(
                    insulinMultiplier: preset.insulinNeedsScaleFactor,
                    correctionRange: preset.correctionRange,
                    guardrail: settingsManager.guardrailForPreset(preset),
                    therapySettingsImpactDisplayState: operation == .end ? .show(settingsImpact) : .hide,
                    isScheduled: false,
                    isActive: temporaryPresetsManager.activePreset?.id == preset.id
                )
                
                actionArea
            }
            .toolbar(.hidden)
            .padding(.top)
            .padding(16)
            .readContentHeight(to: $sheetContentHeight)
        }
        .sheetDetent(height: sheetContentHeight)
    }
}
