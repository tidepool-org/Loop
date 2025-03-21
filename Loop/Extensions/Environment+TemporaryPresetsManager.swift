//
//  Environment+TemporaryPresetManager.swift
//  Loop
//
//  Created by Pete Schwamb on 3/19/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

@MainActor
private struct TemporaryPresetsManagerKey: @preconcurrency EnvironmentKey {
    // Default value should never really be used
    static let defaultValue: TemporaryPresetsManager = TemporaryPresetsManager.placeholder
}

extension EnvironmentValues {
    var temporaryPresetsManager: TemporaryPresetsManager {
        get { self[TemporaryPresetsManagerKey.self] }
        set { self[TemporaryPresetsManagerKey.self] = newValue }
    }
}
