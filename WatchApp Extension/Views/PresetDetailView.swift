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
    let preset: SelectablePreset

    var body: some View {
        VStack(spacing: 10) {
            Text(preset.name)
                .font(.headline)
        }
        .padding()
        .navigationTitle("Preset Details")
        .navigationBarBackButtonHidden(false) // Ensure back button is visible
    }
}
