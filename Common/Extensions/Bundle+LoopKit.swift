//
//  Bundle.swift
//  Loop
//
//  Created by Michael Pangburn on 12/27/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import LoopKitUI


extension Bundle {
    static let linkedPumpManagers = linkedFrameworkClasses(fromInfoDictionaryKey: "PumpManager").compactMap { $0 as? PumpManager.Type }
    static let linkedPumpManagerUIs = linkedFrameworkClasses(fromInfoDictionaryKey: "PumpManagerUI").compactMap { $0 as? PumpManagerUI.Type }
    static let linkedCGMManagers = linkedFrameworkClasses(fromInfoDictionaryKey: "CGMManager").compactMap { $0 as? CGMManager.Type }
    static let linkedCGMManagerUIs = linkedFrameworkClasses(fromInfoDictionaryKey: "CGMManagerUI").compactMap { $0 as? CGMManagerUI.Type }

    private static func linkedFrameworkClasses(fromInfoDictionaryKey plistKey: String) -> [AnyClass] {
        return allFrameworks.flatMap { bundle -> [AnyClass] in
            // Support single class as String or multiple classes as [String]
            let object = bundle.object(forInfoDictionaryKey: plistKey)
            let classNames: [String]
            switch object {
            case let name as String:
                classNames = [name]
            case let names as [String]:
                classNames = names
            default:
                return []
            }

            let bundleName = bundle.bundleName
            let qualifiedClassNames = classNames.map { className in "\(bundleName).\(className)" }
            return qualifiedClassNames.compactMap(NSClassFromString)
        }
    }
}
