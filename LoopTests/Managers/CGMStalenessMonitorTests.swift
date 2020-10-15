//
//  CGMStalenessMonitorTests.swift
//  LoopTests
//
//  Created by Pete Schwamb on 10/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import Foundation
import LoopKit
import HealthKit
@testable import Loop

class CGMStalenessMonitorTests: XCTestCase {
    
    private var latestCGMGlucose: StoredGlucoseSample?
    private var fetchExpectation: XCTestExpectation?
    
    private var storedGlucoseSample: StoredGlucoseSample {
        return StoredGlucoseSample(sampleUUID: UUID(), syncIdentifier: "syncIdentifier", syncVersion: 1, startDate: Date().addingTimeInterval(-.minutes(5)), quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), isDisplayOnly: false, wasUserEntered: false, provenanceIdentifier: "Testing")
    }
    
    private var newGlucoseSample: NewGlucoseSample {
        return NewGlucoseSample(date: Date().addingTimeInterval(-.minutes(1)), quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), isDisplayOnly: false, wasUserEntered: false, syncIdentifier: "syncIdentifier")
    }

    func testInitialValue() {
        let monitor = CGMStalenessMonitor()
        XCTAssert(monitor.cgmDataIsStale)
    }
    
    func testStalenessWithRecentCMGSample() {
        let monitor = CGMStalenessMonitor()
        fetchExpectation = expectation(description: "Fetch latest cgm glucose")
        latestCGMGlucose = storedGlucoseSample
        
        var recievedValues = [Bool]()
        let exp = expectation(description: "expected values")
        
        let cancelable = monitor.$cgmDataIsStale.sink { value in
            recievedValues.append(value)
            if recievedValues.count == 2 {
                exp.fulfill()
            }
        }
        
        monitor.delegate = self
        waitForExpectations(timeout: 2)
        
        XCTAssertNotNil(cancelable)
        XCTAssertEqual(recievedValues, [true, false])
    }
    
    func testStalenessWithNoRecentCGMData() {
        let monitor = CGMStalenessMonitor()
        fetchExpectation = expectation(description: "Fetch latest cgm glucose")
        latestCGMGlucose = nil
        
        var recievedValues = [Bool]()
        let exp = expectation(description: "expected values")
        
        let cancelable = monitor.$cgmDataIsStale.sink { value in
            recievedValues.append(value)
            if recievedValues.count == 2 {
                exp.fulfill()
            }
        }
        
        monitor.delegate = self
        waitForExpectations(timeout: 2)
        
        XCTAssertNotNil(cancelable)
        XCTAssertEqual(recievedValues, [true, true])
    }
    
    func testStalenessNewReadingsArriving() {
        let monitor = CGMStalenessMonitor()
        fetchExpectation = expectation(description: "Fetch latest cgm glucose")
        latestCGMGlucose = nil
        
        var recievedValues = [Bool]()
        let exp = expectation(description: "expected values")
        
        let cancelable = monitor.$cgmDataIsStale.sink { value in
            recievedValues.append(value)
            if recievedValues.count == 2 {
                exp.fulfill()
            }
        }
        
        monitor.delegate = self
        
        monitor.cgmGlucoseSamplesAvailable([newGlucoseSample])
        
        waitForExpectations(timeout: 2)
        
        XCTAssertNotNil(cancelable)
        XCTAssertEqual(recievedValues, [true, false])
    }
}

extension CGMStalenessMonitorTests: CGMStalenessMonitorDelegate {
    func getLatestCGMGlucose(since: Date, completion: @escaping (GlucoseStoreResult<StoredGlucoseSample?>) -> Void) {
        completion(.success(latestCGMGlucose))
        fetchExpectation?.fulfill()
    }
}
