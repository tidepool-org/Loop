//
//  HKHealthStoreQueryMock.swift
//  LoopTests
//
//  Created by Rick Pasetto on 6/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import XCTest

class HKHealthStoreQueryMock: HKHealthStore {
    var lastQuery: HKQuery?
    let expectation: XCTestExpectation
    init(expectation: XCTestExpectation) {
        self.expectation = expectation
        super.init()
    }
    override func execute(_ query: HKQuery) {
        lastQuery = query
        expectation.fulfill()
    }
}

