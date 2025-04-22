//
//  Deeplink.swift
//  Loop
//
//  Created by Noah Brauner on 8/9/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm

enum Deeplink: Hashable {
    
    struct AppSource: Hashable {
        let name: String
        let bundleId: String?
    }
    
    enum Host: String, CaseIterable {
        case carbEntry = "carb-entry"
        case bolus = "manual-bolus"
        case preMeal = "pre-meal-preset"
        case customPresets = "custom-presets"
    }
    
    enum CarbEntryLink: Hashable {
        case carbEntryDetected(value: LoopQuantity, source: AppSource?)
    }
    
    case carbEntry(CarbEntryLink?)
    
    case bolus
    case preMeal
    case customPresets
    
    var host: Host {
        switch self {
        case .carbEntry: .carbEntry
        case .bolus: .bolus
        case .preMeal: .preMeal
        case .customPresets: .customPresets
        }
    }
    
    init?(url: URL?) {
        guard let url, let host = url.host, let deeplinkHost = Deeplink.Host.allCases.first(where: { $0.rawValue == host }) else {
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        
        switch deeplinkHost {
        case .carbEntry:
            if let value = components?.queryItems?.first(where: { $0.name == "value" })?.value, let doubleValue = Double(value) {
                let sourceBundleId = components?.queryItems?.first(where: { $0.name == "sourceBundleId" })?.value
                let sourceName = components?.queryItems?.first(where: { $0.name == "sourceName" })?.value
                
                var source: AppSource?
                if let sourceName {
                    source = AppSource(name: sourceName, bundleId: sourceBundleId)
                }
                
                self = .carbEntry(.carbEntryDetected(value: LoopQuantity(unit: .gram, doubleValue: doubleValue), source: source))
            } else {
                self = .carbEntry(nil)
            }
        case .bolus:
            self = .bolus
        case .preMeal:
            self = .preMeal
        case .customPresets:
            self = .customPresets
        }
    }
}
