//
//  NewCustomPreset.swift
//  Loop
//
//  Created by Pete Schwamb on 2/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm

struct NewCustomPreset {
    var name: String = ""
    var insulinMultiplier: Double = 1
    var correctionRange: ClosedRange<LoopQuantity>?
}
