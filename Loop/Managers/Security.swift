//
//  Security.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2023-09-07.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import LoopKit

extension Security {

    typealias RawValue = [String: Any]

    var rawValue: RawValue {
        return ["securityIdentifier": pluginIdentifier]
    }
}
