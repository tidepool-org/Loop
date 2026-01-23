//
//  PresetsHistoryView.swift
//  Loop
//
//  Created by Cameron Ingham on 11/27/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import SwiftUI

struct PresetsHistoryView: View {
    @Environment(\.colorPalette) private var colorPalette
    @Environment(\.settingsManager) private var settingsManager
    @Environment(\.temporaryPresetsManager) private var temporaryPresetsManager

    let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    var overridesByDate: Dictionary<Date, [TemporaryScheduleOverride]> {
        Dictionary(
            grouping: temporaryPresetsManager.presetHistory.recentEvents
                .map(\.override)
                .filter({ !$0.isActive() })
                .sorted(by: { $0.actualEndDate > $1.actualEndDate })
        ) { override in
            Calendar.current.startOfDay(for: override.startDate)
        }
    }
    
    var body: some View {
        List {
            ForEach(Array(overridesByDate.keys.sorted(by: >)), id: \.self) { date in
                Section(date.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(overridesByDate[date] ?? [], id: \.self) { override in
                        LabeledContent {
                            VStack(alignment: .trailing, spacing: 8) {
                                Text("Duration")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                
                                durationText(for: override)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(override.startDate.formatted(date: .omitted, time: .shortened))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                
                                if let preset = temporaryPresetsManager.selectablePresets.first(where: { $0.id == override.presetId }) {
                                    HStack(spacing: 4) {
                                        if let icon = preset.icon, !icon.isEmpty {
                                            PresetSymbolView(icon)
                                        }
                                        
                                        Text(preset.name)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Recent Events")
    }
    
    @ViewBuilder
    func durationText(for override: TemporaryScheduleOverride) -> some View {
        switch override.duration {
        case let .finite(scheduledDuration):
            let actualDuration = override.actualDuration.timeInterval
            if let scheduledDurationString = formatter.string(from: scheduledDuration), let actualDurationString = formatter.string(from: actualDuration) {
                if scheduledDuration <= actualDuration {
                    Text(actualDurationString)
                        .foregroundStyle(.primary)
                } else {
                    Text(actualDurationString)
                        .foregroundStyle(.primary)
                        .fontWeight(.semibold)
                    + Text(" / ")
                    + Text(scheduledDurationString)
                }
            }
        case .indefinite:
            let actualDuration = override.actualDuration.timeInterval
            if actualDuration != .infinity,
               let durationString = formatter.string(from: actualDuration)
            {
                Text(durationString)
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            }
        }
    }
}
