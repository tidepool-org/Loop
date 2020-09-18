//
//  ManualGlucoseState.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2020-09-18.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

struct ManualGlucoseState: SensorDisplayable {
    let isStateValid: Bool
    let trendType: GlucoseTrend?
    let isLocal: Bool
    let glucoseValueType: GlucoseValueType?
    
    init(glucoseValueType: GlucoseValueType?) {
        isStateValid = true
        trendType = nil
        isLocal = true
        self.glucoseValueType = glucoseValueType
    }
}
