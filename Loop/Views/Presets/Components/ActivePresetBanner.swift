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
    
    var symbol: Text? {
        switch override.context {
        case .preMeal:
            return Text(Image("Pre-Meal-symbol"))
        case .preset(let preset):
            guard let symbol = preset.symbol else {
                return nil
            }
            
            switch symbol.symbolType {
            case .emoji:
                return Text(symbol.value)
            case .systemImage:
                return Text(Image(systemName: symbol.value))
            case .image:
                return Text(Image(symbol.value))
            }
        case .activity(let activity):
            guard let symbol = activity.preset.symbol else {
                return nil
            }
            
            switch symbol.symbolType {
            case .emoji:
                return Text(symbol.value)
            case .systemImage:
                return Text(Image(systemName: symbol.value))
            case .image:
                return Text(Image(symbol.value))
            }
        case .custom:
            return nil
        }
    }

    var titleText: Text {
        switch override.context {
        case .preMeal:
            Text(NSLocalizedString("Pre-Meal", comment: "Status row title for premeal override enabled (leading space is to separate from symbol)"))
        case .preset(let preset):
            Text(String(format: NSLocalizedString("%@", comment: "The format for an active custom preset. (1: preset name)"), preset.name))
        case .activity(let activity):
            Text(String(format: NSLocalizedString("%@", comment: "The format for an active activity preset. (1: preset name)"), activity.preset.name))
        case .custom:
            Text(NSLocalizedString("Single Use Preset", comment: "The title of the cell indicating a generic custom preset is enabled"))
        }
    }
    
    var accessibilityIdentifier: String {
        switch override.context {
        case .preMeal:
            "text_PreMealPresetCellTitle"
        case .preset:
            "text_CustomPresetCellTitle"
        case .activity:
            "text_ActivityPresetCellTitle"
        case .custom:
            "text_OneTimePresetCellTitle"
        }
    }
    
    @ViewBuilder
    var title: some View {
        Group {
            if let symbol {
                symbol + Text(" ") + titleText
            } else {
                titleText
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
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
                    Text(NSLocalizedString("on until turned off", comment: "The format for the description of an indefinite custom preset end date"))
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
