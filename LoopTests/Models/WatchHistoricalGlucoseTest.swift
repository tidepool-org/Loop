//
//  WatchHistoricalGlucoseTest.swift
//  LoopTests
//
//  Created by Darin Krauss on 10/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit

@testable import Loop

class WatchHistoricalGlucoseTests: XCTestCase {
    private lazy var objects: [SyncGlucoseObject] = {
        return [SyncGlucoseObject(uuid: UUID(),
                                  provenanceIdentifier: UUID().uuidString,
                                  syncIdentifier: UUID().uuidString,
                                  syncVersion: 4,
                                  value: 123.45,
                                  unitString: "mg/dL",
                                  startDate: Date(timeIntervalSinceReferenceDate: .hours(100)),
                                  isDisplayOnly: false,
                                  wasUserEntered: true),
                SyncGlucoseObject(uuid: UUID(),
                                  provenanceIdentifier: UUID().uuidString,
                                  syncIdentifier: UUID().uuidString,
                                  syncVersion: 2,
                                  value: 7.2,
                                  unitString: "mmol/L",
                                  startDate: Date(timeIntervalSinceReferenceDate: .hours(99)),
                                  isDisplayOnly: true,
                                  wasUserEntered: false),
                SyncGlucoseObject(uuid: UUID(),
                                  provenanceIdentifier: UUID().uuidString,
                                  syncIdentifier: UUID().uuidString,
                                  syncVersion: 7,
                                  value: 187.65,
                                  unitString: "mg/dL",
                                  startDate: Date(timeIntervalSinceReferenceDate: .hours(98)),
                                  isDisplayOnly: false,
                                  wasUserEntered: false),
        ]
    }()
    private lazy var objectsEncoded: Data = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try! encoder.encode(self.objects)
    }()
    private lazy var rawValue: WatchHistoricalGlucose.RawValue = {
        return [
            "o": objectsEncoded
        ]
    }()

    func testDefaultInitializer() {
        let glucose = WatchHistoricalGlucose(objects: self.objects)
        XCTAssertEqual(glucose.objects, self.objects)
    }

    func testRawValueInitializer() {
        let glucose = WatchHistoricalGlucose(rawValue: self.rawValue)
        XCTAssertEqual(glucose?.objects, self.objects)
    }

    func testRawValueInitializerMissingObjects() {
        var rawValue = self.rawValue
        rawValue["o"] = nil
        XCTAssertNil(WatchHistoricalGlucose(rawValue: rawValue))
    }

    func testRawValueInitializerInvalidObjects() {
        var rawValue = self.rawValue
        rawValue["o"] = Data()
        XCTAssertNil(WatchHistoricalGlucose(rawValue: rawValue))
    }

    func testRawValue() {
        let rawValue = WatchHistoricalGlucose(objects: self.objects).rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["o"] as? Data, self.objectsEncoded)
    }
}
