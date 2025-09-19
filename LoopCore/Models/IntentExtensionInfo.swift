//
//  IntentExtensionInfo.swift
//  Loop Intent Extension
//
//  Created by Anna Quinlan on 10/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public struct IntentExtensionInfo: RawRepresentable {
    public typealias RawValue = [String: Any]

    public var overridePresetNames: [String]?

    init() { }
    
    public init(rawValue: RawValue) {
        overridePresetNames = rawValue["overridePresetNames"] as? [String]
    }
    
    public init(overridePresetNames: [String]?) {
        self.overridePresetNames = overridePresetNames
    }
    
    public var rawValue: RawValue {
        var raw: RawValue = [:]
        
        raw["overridePresetNames"] = overridePresetNames
        
        return raw
    }
}
