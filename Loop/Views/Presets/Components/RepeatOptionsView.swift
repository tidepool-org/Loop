//
//  RepeatOptionsView.swift
//  Loop
//
//  Created by Pete Schwamb on 3/14/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//
import SwiftUI

struct RepeatOptionView: View {
    let repeatOptions: PresetScheduleRepeatOptions

    private var selectedDays: [PresetScheduleRepeatOptions] {
        PresetScheduleRepeatOptions.allCases.filter { repeatOptions.contains($0) }
    }

    private var isSingleDay: Bool {
        selectedDays.count == 1
    }

    var body: some View {
        if repeatOptions == .none {
            Text(repeatOptions.description)
                .tint(.secondary)
        } else if isSingleDay {
            Text(selectedDays[0].description)
                .foregroundColor(.secondary)
        } else {
            HStack(spacing: 4) {
                ForEach(PresetScheduleRepeatOptions.allCases, id: \.rawValue) { day in
                    Text(String(day.description.first!))
                        .font(.system(size: 12))
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(repeatOptions.contains(day) ? Color.blue : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(repeatOptions.contains(day) ? .white : .gray)
                }
            }
        }
    }
}

