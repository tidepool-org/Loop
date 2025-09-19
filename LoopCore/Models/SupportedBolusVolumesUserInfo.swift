//
//  SupportedBolusVolumesUserInfo.swift
//  Loop
//
//  Created by Michael Pangburn on 6/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

public struct SupportedBolusVolumesUserInfo {
    public var supportedBolusVolumes: [Double]

    public init(supportedBolusVolumes: [Double]) {
        self.supportedBolusVolumes = supportedBolusVolumes
    }
}

extension SupportedBolusVolumesUserInfo: RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum Key: String {
        case version = "v"
        case name = "name"
        case supportedBolusVolumes = "sbv"
    }

    public static let name = "SupportedBolusVolumesUserInfo"
    static let version = 1

    public init?(rawValue: RawValue) {
        guard
            rawValue[Key.version.rawValue] as? Int == Self.version,
            rawValue[Key.name.rawValue] as? String == Self.name,
            let supportedBolusVolumes = rawValue[Key.supportedBolusVolumes.rawValue] as? [Double]
        else {
            return nil
        }

        self.init(supportedBolusVolumes: supportedBolusVolumes)
    }

    public var rawValue: RawValue {
        [
            Key.version.rawValue: Self.version,
            Key.name.rawValue: Self.name,
            Key.supportedBolusVolumes.rawValue: supportedBolusVolumes
        ]
    }
}
