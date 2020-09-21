//
//  ManualGlucoseDisplayable.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2020-09-18.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

struct ManualGlucoseDisplayable: GlucoseDisplayable {
    let isStateValid: Bool
    let trendType: GlucoseTrend?
    let isLocal: Bool
    let glucoseRangeCategory: GlucoseRangeCategory?
    
    init(glucoseRangeCategory: GlucoseRangeCategory?) {
        isStateValid = true
        trendType = nil
        isLocal = true
        self.glucoseRangeCategory = glucoseRangeCategory
    }
}
