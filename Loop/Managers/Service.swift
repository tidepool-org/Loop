//
//  Service.swift
//  Loop
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import MockKit


#if DEBUG
let staticServices: [Service.Type] = [MockService.self]
#else
let staticServices: [Service.Type] = []
#endif


let staticServicesByIdentifier: [String: Service.Type] = staticServices.reduce(into: [:]) { (map, Type) in
    map[Type.managerIdentifier] = Type
}


let availableStaticServices = staticServices.map { (Type) -> AvailableDevice in
    return AvailableDevice(identifier: Type.managerIdentifier, localizedTitle: Type.localizedTitle)
}


func ServiceFromRawValue(_ rawValue: [String: Any]) -> Service? {
    guard let managerIdentifier = rawValue["managerIdentifier"] as? String,
        let rawState = rawValue["state"] as? Service.RawStateValue,
        let Manager = staticServicesByIdentifier[managerIdentifier]
    else {
        return nil
    }

    return Manager.init(rawState: rawState)
}


extension Service {

    var rawValue: RawStateValue {
        return [
            "managerIdentifier": type(of: self).managerIdentifier,
            "state": self.rawState
        ]
    }

}
