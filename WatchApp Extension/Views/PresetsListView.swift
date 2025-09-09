//
//  PresetsList.swift
//  Loop
//
//  Created by Pete Schwamb on 9/9/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopCore

struct PresetListView: View {
    let presets: [SelectablePreset]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    ForEach(presets) { preset in
                        NavigationLink(value: preset) {
                            PresetWatchCard(preset)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Preset")
            .navigationDestination(for: SelectablePreset.self) { preset in
                PresetDetailView(preset: preset)
            }
        }
    }
}

extension TemporaryPreset: @retroactive Identifiable {

}
