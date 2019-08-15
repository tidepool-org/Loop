//
//  PumpManager.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import MinimedKit
import OmniKit
import MockKit


public struct AvailableDevice {
    let identifier: String
    let localizedTitle: String
}

#if DEBUG
let staticPumpManagers: [PumpManager.Type] = [
    OmnipodPumpManager.self,
    MinimedPumpManager.self,
    MockPumpManager.self,
]
#else
let staticPumpManagers: [PumpManager.Type] = [
    OmnipodPumpManager.self,
    MinimedPumpManager.self,
]
#endif

let staticPumpManagersByIdentifier: [String: PumpManager.Type] = staticPumpManagers.reduce(into: [:]) { (map, Type) in
    map[Type.managerIdentifier] = Type
}

let availableStaticPumpManagers = staticPumpManagers.map { (Type) -> AvailableDevice in
    return AvailableDevice(identifier: Type.managerIdentifier, localizedTitle: Type.localizedTitle)
}

extension PumpManager {
    var rawValue: [String: Any] {
        return [
            "managerIdentifier": type(of: self).managerIdentifier,
            "state": self.rawState
        ]
    }
}
