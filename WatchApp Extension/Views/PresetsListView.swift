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
    @Environment(LoopDataManager.self) var loopManager
    @Environment(\.dismiss) private var dismiss

    let presets: [SelectablePreset]
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView(.vertical) {
            ForEach(presets) { preset in
                PresetWatchCard(preset)
                    .onTapGesture {
                        path.append(preset)
                    }
            }
            .padding()
        }
        .navigationTitle("Select Preset")
        .navigationDestination(for: SelectablePreset.self) { preset in
            PresetConfirmationView(preset: preset)
        }
    }
}
