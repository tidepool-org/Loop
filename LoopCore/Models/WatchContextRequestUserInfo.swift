//
//  WatchContextRequestUserInfo.swift
//  Loop
//
//  Created by Pete Schwamb on 2/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation


public struct WatchContextRequestUserInfo {
    public init() {}
}

extension WatchContextRequestUserInfo: RawRepresentable {
    public typealias RawValue = [String: Any]

    public static let name = "WatchContextRequestUserInfo"

    public init?(rawValue: RawValue) {
        guard rawValue["name"] as? String == WatchContextRequestUserInfo.name else {
            return nil
        }
    }

    public var rawValue: RawValue {
        return [
            "name": WatchContextRequestUserInfo.name,
        ]
    }
}
