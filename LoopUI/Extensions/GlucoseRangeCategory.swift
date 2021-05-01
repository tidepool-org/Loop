//
//  GlucoseRangeCategory.swift
//  LoopUI
//
//  Created by Nathaniel Hamming on 2020-07-28.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

extension GlucoseRangeCategoryColor {
    var uicolor: UIColor {
        switch self {
        case .label:
            return .label
        case .critical:
            return .critical
        case .warning:
            return .warning
        case .glucose:
            return .glucose
        }
    }
}

extension GlucoseRangeCategory {
    public var glucoseColor: UIColor {
        return self.glucoseCategoryColor.uicolor
    }
    
    public var trendColor: UIColor {
        return self.trendCategoryColor.uicolor
    }
}
