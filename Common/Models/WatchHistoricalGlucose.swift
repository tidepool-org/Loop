//
//  WatchHistoricalGlucose.swift
//  Loop
//
//  Created by Bharat Mediratta on 6/22/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

struct WatchHistoricalGlucose {
    let objects: [SyncGlucoseObject]
}

extension WatchHistoricalGlucose: RawRepresentable {
    typealias RawValue = [String: Any]

    init?(rawValue: RawValue) {
        guard let rawObjects = rawValue["o"] as? Data,
            let objects = try? Self.decoder.decode([SyncGlucoseObject].self, from: rawObjects) else {
                return nil
        }
        self.objects = objects
    }

    var rawValue: RawValue {
        guard let rawObjects = try? Self.encoder.encode(objects) else {
            return [:]
        }
        return [
            "o": rawObjects
        ]
    }

    private static var encoder: PropertyListEncoder {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }

    private static var decoder: PropertyListDecoder = PropertyListDecoder()
}
