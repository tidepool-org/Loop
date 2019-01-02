//
//  CGMManager.swift
//  Loop
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import LoopKit


let allCGMManagers = Bundle.linkedCGMManagers

private let managersByIdentifier: [String: CGMManager.Type] = allCGMManagers.reduce(into: [:]) { (map, Type) in
    map[Type.managerIdentifier] = Type
}


func CGMManagerFromRawValue(_ rawValue: [String: Any]) -> CGMManager? {
    guard let managerIdentifier = rawValue["managerIdentifier"] as? String,
        let rawState = rawValue["state"] as? CGMManager.RawStateValue,
        let Manager = managersByIdentifier[managerIdentifier]
    else {
        return nil
    }

    return Manager.init(rawState: rawState)
}


extension CGMManager {
    var rawValue: [String: Any] {
        return [
            "managerIdentifier": type(of: self).managerIdentifier,
            "state": self.rawState
        ]
    }
}
