//
//  LoopSettings+Loop.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopCore
import LoopKit

// MARK: - Static configuration
extension LoopSettings {
    var enabledEffects: PredictionInputEffect {
        var inputs = PredictionInputEffect.all
        if !retrospectiveCorrectionEnabled {
            inputs.remove(.retrospection)
        }
        return inputs
    }
}
