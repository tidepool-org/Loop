//
//  EditPresetDurationView.swift
//  Loop
//
//  Created by Cameron Ingham on 12/12/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import SwiftUI

struct EditPresetDurationView: View {
    @Environment(\.temporaryPresetsManager) private var temporaryPresetsManager
    @Environment(\.settingsManager) private var settingsManager
    @Environment(\.colorPalette) private var colorPalette
    @Environment(\.dismiss) private var dismiss
    
    @State var dateSelection: Date = Date()

    private let currentDate: Date = Date()

    var preset: SelectablePreset? {
        temporaryPresetsManager.selectablePresets.first { $0.id == temporaryPresetsManager.activeOverride?.presetId }
    }

    var buttonDisabled: Bool {
        if case .finite = temporaryPresetsManager.activeOverride?.duration {
            return dateSelection == temporaryPresetsManager.activeOverride?.actualEndDate
        } else if case .indefinite = temporaryPresetsManager.activeOverride?.duration {
            return false
        } else {
            return dateSelection == currentDate
        }
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.secondarySystemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    preset?.title(font: .largeTitle, iconSize: 36, colorPalette: colorPalette)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    DatePicker("On until", selection: $dateSelection, displayedComponents: .hourAndMinute)
                        .padding(6)
                        .padding(.leading, 10)
                        .background(Color(UIColor.systemBackground).cornerRadius(10))
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                Button("Save") {
                    temporaryPresetsManager.updateActivePresetDuration(newEndDate: dateSelection)
                    dismiss()
                }
                .buttonStyle(ActionButtonStyle())
                .padding([.top, .horizontal])
                .background(Color(UIColor.secondarySystemBackground))
                .disabled(buttonDisabled)
                .accessibilityIdentifier("button_Save")
            }
        }
        .onAppear {
            if let activeOverride = temporaryPresetsManager.activeOverride {
                if case let .finite(timeInterval) = activeOverride.duration {
                    dateSelection = activeOverride.startDate.addingTimeInterval(timeInterval)
                } else {
                    dateSelection = currentDate
                }
            }
        }
    }
}
