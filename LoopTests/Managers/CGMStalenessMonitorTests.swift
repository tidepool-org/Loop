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
        return StoredGlucoseSample(uuid: UUID(), provenanceIdentifier: UUID().uuidString, syncIdentifier: "syncIdentifier", syncVersion: 1, startDate: Date().addingTimeInterval(-.minutes(5)), quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), condition: nil, trend: .flat, trendRate: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 0.0), isDisplayOnly: false, wasUserEntered: false, device: nil, healthKitEligibleDate: nil)
    }
    
    private var newGlucoseSample: NewGlucoseSample {
        return NewGlucoseSample(date: Date().addingTimeInterval(-.minutes(1)), quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), condition: nil, trend: .flat, trendRate: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 0.0), isDisplayOnly: false, wasUserEntered: false, syncIdentifier: "syncIdentifier")
    }

    func testInitialValue() {
        let monitor = CGMStalenessMonitor()
        XCTAssert(monitor.cgmDataIsStale)
    }
    
    func testStalenessWithRecentCMGSample() async throws {
        let monitor = CGMStalenessMonitor()
        fetchExpectation = expectation(description: "Fetch latest cgm glucose")
        latestCGMGlucose = storedGlucoseSample
        
        var receivedValues = [Bool]()
        let exp = expectation(description: "expected values")
        
        let cancelable = monitor.$cgmDataIsStale.sink { value in
            receivedValues.append(value)
            if receivedValues.count == 2 {
                exp.fulfill()
            }
        }
        
        monitor.delegate = self

        await monitor.checkCGMStaleness()

        await fulfillment(of: [fetchExpectation!, exp], timeout: 2)

        XCTAssertNotNil(cancelable)
        XCTAssertEqual(receivedValues, [true, false])
    }
    
    func testStalenessWithNoRecentCGMData() async throws {
        let monitor = CGMStalenessMonitor()
        fetchExpectation = expectation(description: "Fetch latest cgm glucose")
        latestCGMGlucose = nil
        
        var receivedValues = [Bool]()
        let exp = expectation(description: "expected values")
        
        let cancelable = monitor.$cgmDataIsStale.sink { value in
            receivedValues.append(value)
            if receivedValues.count == 2 {
                exp.fulfill()
            }
        }
        
        monitor.delegate = self

        await monitor.checkCGMStaleness()

        await fulfillment(of: [fetchExpectation!, exp], timeout: 2)

        XCTAssertNotNil(cancelable)
        XCTAssertEqual(receivedValues, [true, true])
    }
    
    func testStalenessNewReadingsArriving() async throws {
        let monitor = CGMStalenessMonitor()
        fetchExpectation = expectation(description: "Fetch latest cgm glucose")
        latestCGMGlucose = nil
        
        var receivedValues = [Bool]()
        let exp = expectation(description: "expected values")
        
        let cancelable = monitor.$cgmDataIsStale.sink { value in
            receivedValues.append(value)
            if receivedValues.count == 2 {
                exp.fulfill()
            }
        }
        
        monitor.delegate = self

        await monitor.checkCGMStaleness()

        monitor.cgmGlucoseSamplesAvailable([newGlucoseSample])

        await fulfillment(of: [fetchExpectation!, exp], timeout: 2)

        XCTAssertNotNil(cancelable)
        XCTAssertEqual(receivedValues, [true, true, false])
    }
}

extension CGMStalenessMonitorTests: CGMStalenessMonitorDelegate {
    public func getLatestCGMGlucose(since: Date) async throws -> StoredGlucoseSample? {
        fetchExpectation?.fulfill()
        return latestCGMGlucose
    }
}
