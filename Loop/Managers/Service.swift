//
//  Service.swift
//  Loop
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import MockKit
import AmplitudeServiceKit
import LogglyServiceKit
import NightscoutServiceKit
import TidepoolServiceKit


/// The order here specifies the order in the service selection popup
let serviceTypes: [Service.Type] = [
    TidepoolService.self,
    NightscoutService.self,
    LogglyService.self,
    AmplitudeService.self,
    MockService.self,
]


private let serviceTypesByIdentifier: [String: Service.Type] = serviceTypes.reduce(into: [:]) { (map, Type) in
    map[Type.managerIdentifier] = Type
}


func ServiceFromRawValue(_ rawValue: [String: Any]) -> Service? {
    guard let managerIdentifier = rawValue["managerIdentifier"] as? String,
        let rawState = rawValue["state"] as? Service.RawStateValue,
        let serviceType = serviceTypesByIdentifier[managerIdentifier]
    else {
        return nil
    }

    return serviceType.init(rawState: rawState)
}


extension Service {

    var rawValue: RawStateValue {
        return [
            "managerIdentifier": type(of: self).managerIdentifier,
            "state": self.rawState
        ]
    }

}
