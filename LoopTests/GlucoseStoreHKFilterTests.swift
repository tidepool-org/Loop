//
//  GlucoseStoreHKFilterTests.swift
//  LoopTests
//
//  Created by Rick Pasetto on 6/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import XCTest
import LoopKit

class GlucoseStoreHKFilterTests: XCTestCase {
    let sampleFromCurrentApp: [String : Any] = [ "endDate": Date(), "source": HKSource.default() ]
    let sampleFromOutsideCurrentApp: [String : Any] = [ "endDate": Date(), "source": "other" ]

    func testEntriesFromAllSources() {
        let e = expectation(description: "\(#function)")
        e.expectedFulfillmentCount = 2
        let pc = PersistenceController(directoryURL: URL.init(fileURLWithPath: ""))
        let mockHKStore = HKHealthStoreQueryMock(expectation: e)
        let glucoseStore = GlucoseStore(healthStore: mockHKStore, observeHealthKitForCurrentAppOnly: false, cacheStore: pc)
        glucoseStore.getGlucoseSamples(start: Date.distantPast) { _ in }
        wait(for: [e], timeout: 1.0)
        guard let predicate = try? XCTUnwrap(mockHKStore.lastQuery?.predicate) else { return }
        XCTAssertTrue(predicate.evaluate(with: sampleFromCurrentApp))
        XCTAssertTrue(predicate.evaluate(with: sampleFromOutsideCurrentApp))
    }
    
    func testEntriesFromCurrentAppOnly() {
        let e = expectation(description: "\(#function)")
        e.expectedFulfillmentCount = 2
        let pc = PersistenceController(directoryURL: URL.init(fileURLWithPath: ""))
        let mockHKStore = HKHealthStoreQueryMock(expectation: e)
        let glucoseStore = GlucoseStore(healthStore: mockHKStore, observeHealthKitForCurrentAppOnly: true, cacheStore: pc)
        glucoseStore.getGlucoseSamples(start: Date.distantPast) { _ in }
        wait(for: [e], timeout: 1.0)
        guard let predicate = try? XCTUnwrap(mockHKStore.lastQuery?.predicate) else { return }
        XCTAssertTrue(predicate.evaluate(with: sampleFromCurrentApp))
        XCTAssertFalse(predicate.evaluate(with: sampleFromOutsideCurrentApp))
    }
}
