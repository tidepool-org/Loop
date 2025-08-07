//
//  ActivePresetBanner.swift
//  Loop
//
//  Created by Cameron Ingham on 8/7/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

struct ActivePresetBanner: View {
    
    @Environment(\.temporaryPresetsManager) private var temporaryPresetsManager
    
    let override: TemporaryScheduleOverride

    @ViewBuilder
    var title: some View {
        switch override.context {
        case .preMeal:
            Group {
                Text(Image("Pre-Meal-symbol")) + Text(" ") + Text(NSLocalizedString("Pre-meal Preset", comment: "Status row title for premeal override enabled (leading space is to separate from symbol)"))
            }
            .accessibilityIdentifier("text_PreMealPresetCellTitle")
        case .legacyWorkout:
            Group {
                Text(Image("workout-symbol")) + Text(" ") + Text( NSLocalizedString("Workout Preset", comment: "Status row title for workout override enabled (leading space is to separate from symbol)"))
            }
            .accessibilityIdentifier("text_WorkoutPresetCellTitle")
        case .preset(let preset):
            Text(String(format: NSLocalizedString("%@ %@", comment: "The format for an active custom preset. (1: preset symbol)(2: preset name)"), preset.symbol, preset.name))
        case .custom:
            Text(NSLocalizedString("Single Use Preset", comment: "The title of the cell indicating a generic custom preset is enabled"))
        }
    }
    
    @ViewBuilder
    var subtitle: some View {
        if override.isActive() {
            if let preset = temporaryPresetsManager.selectablePresets.first(where: { $0.id == override.presetId }), case .preMeal(_) = preset {
                Text(NSLocalizedString("on until carbs added", comment: "The format for the description of a premeal preset end date"))
                    .accessibilityIdentifier("text_PresetActiveOn")
            } else {
                switch override.duration {
                case .finite:
                    let endTimeText = DateFormatter.localizedString(from: override.activeInterval.end, dateStyle: .none, timeStyle: .short)
                    Text(String(format: NSLocalizedString("on until %@", comment: "The format for the description of a finite custom preset end date"), endTimeText))
                        .accessibilityIdentifier("text_PresetActiveOn")
                case .indefinite:
                    Text(NSLocalizedString("on indefinitely", comment: "The format for the description of an indefinite custom preset end date"))
                        .accessibilityIdentifier("text_PresetActiveOn")
                }
            }
        } else {
            let startTimeText = DateFormatter.localizedString(from: override.startDate, dateStyle: .none, timeStyle: .short)
            Text(String(format: NSLocalizedString("starting at %@", comment: "The format for the description of a custom preset start date"), startTimeText))
        }
    }
    
    var body: some View {
        HStack {
            title
                .font(.body.weight(.semibold))
            
            Spacer()
            
            subtitle
                .font(.subheadline)
        }
        .padding()
        .foregroundStyle(Color(UIColor.systemBackground))
        .background(Color.presets)
    }
}
