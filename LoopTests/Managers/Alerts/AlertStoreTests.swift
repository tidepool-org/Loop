//
//  AlertStoreTests.swift
//  LoopTests
//
//  Created by Rick Pasetto on 5/19/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData
import LoopKit
import XCTest
@testable import Loop

class AlertStoreTests: XCTestCase {
    
    var alertStore: AlertStore!
    
    static let identifier1 = DeviceAlert.Identifier(managerIdentifier: "managerIdentifier", alertIdentifier: "alertIdentifier")
    let alert1 = DeviceAlert(identifier: identifier1, foregroundContent: nil, backgroundContent: nil, trigger: .immediate, sound: nil)
    
    override func setUp() {
        alertStore = AlertStore()
    }
    
    override func tearDown() {
        alertStore = nil
    }
    
    func testRecordIssued() {
        let expect = self.expectation(description: #function)
        alertStore.recordIssued(alert: alert1, at: Date.distantPast) {
            switch $0 {
            case .failure(let error): XCTFail("Unexpected \(error)")
            case .success:
                self.alertStore.fetch(identifier: Self.identifier1) {
                    switch $0 {
                        case .failure(let error): XCTFail("Unexpected \(error)")
                        case .success(let storedAlerts):
                            XCTAssertEqual(1, storedAlerts.count)
                            XCTAssertEqual(Self.identifier1.value, storedAlerts[0].identifier)
                            XCTAssertEqual(Date.distantPast, storedAlerts[0].issuedTimestamp)
                            XCTAssertNil(storedAlerts[0].acknowledgedTimestamp)
                            XCTAssertNil(storedAlerts[0].retractedTimestamp)
                    }
                    expect.fulfill()
                }
            }
        }
        wait(for: [expect], timeout: 1)
    }
    
    func testRecordAcknowledged() {
        let expect = self.expectation(description: #function)
        let issuedDate = Date.distantPast
        let acknowledgedDate = issuedDate.addingTimeInterval(1)
        alertStore.recordIssued(alert: alert1, at: Date.distantPast) {
            switch $0 {
            case .failure(let error): XCTFail("Unexpected \(error)")
            case .success:
                self.alertStore.recordAcknowledgement(of: Self.identifier1, at: acknowledgedDate) {
                    switch $0 {
                    case .failure(let error): XCTFail("Unexpected \(error)")
                    case .success:
                        self.alertStore.fetch(identifier: Self.identifier1) {
                            switch $0 {
                            case .failure(let error): XCTFail("Unexpected \(error)")
                            case .success(let storedAlerts):
                                XCTAssertEqual(1, storedAlerts.count)
                                XCTAssertEqual(Self.identifier1.value, storedAlerts[0].identifier)
                                XCTAssertEqual(issuedDate, storedAlerts[0].issuedTimestamp)
                                XCTAssertEqual(acknowledgedDate, storedAlerts[0].acknowledgedTimestamp)
                                XCTAssertNil(storedAlerts[0].retractedTimestamp)
                            }
                            expect.fulfill()
                        }
                    }
                }
            }
        }
        wait(for: [expect], timeout: 1)
    }
    
    func testRecordRetracted() {
        let expect = self.expectation(description: #function)
        let issuedDate = Date.distantPast
        let retractedDate = issuedDate.addingTimeInterval(2)
        alertStore.recordIssued(alert: alert1, at: Date.distantPast) {
            switch $0 {
            case .failure(let error): XCTFail("Unexpected \(error)")
            case .success:
                self.alertStore.recordRetraction(of: Self.identifier1, at: retractedDate) {
                    switch $0 {
                    case .failure(let error): XCTFail("Unexpected \(error)")
                    case .success:
                        self.alertStore.fetch(identifier: Self.identifier1) {
                            switch $0 {
                            case .failure(let error): XCTFail("Unexpected \(error)")
                            case .success(let storedAlerts):
                                XCTAssertEqual(1, storedAlerts.count)
                                XCTAssertEqual(Self.identifier1.value, storedAlerts[0].identifier)
                                XCTAssertEqual(issuedDate, storedAlerts[0].issuedTimestamp)
                                XCTAssertEqual(retractedDate, storedAlerts[0].retractedTimestamp)
                                XCTAssertNil(storedAlerts[0].acknowledgedTimestamp)
                            }
                            expect.fulfill()
                        }
                    }
                }
            }
        }
        wait(for: [expect], timeout: 1)
    }
}
