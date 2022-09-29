//
//  AlertMuterTests.swift
//  LoopTests
//
//  Created by Nathaniel Hamming on 2022-09-29.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import Loop

final class AlertMuterTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitialization() {
        var alertMuter = AlertMuter(enabled: false, duration: AlertMuter.allowedDurations[1])
        XCTAssertFalse(alertMuter.configuration.enabled)
        XCTAssertEqual(alertMuter.configuration.duration, AlertMuter.allowedDurations[1])
        XCTAssertNil(alertMuter.configuration.startTime)

        alertMuter = AlertMuter(enabled: true)
        XCTAssertTrue(alertMuter.configuration.enabled)
        XCTAssertEqual(alertMuter.configuration.duration, AlertMuter.allowedDurations[0])
        XCTAssertNotNil(alertMuter.configuration.startTime)
    }

    func testRawValue() {
        let alertMuter = AlertMuter(enabled: true)
        let rawValue = alertMuter.configuration.rawValue
        XCTAssertEqual(rawValue["enabled"] as? Bool, alertMuter.configuration.enabled)
        XCTAssertEqual(rawValue["duration"] as? TimeInterval, alertMuter.configuration.duration)
        XCTAssertEqual(rawValue["startTime"] as? Date, alertMuter.configuration.startTime)
    }

    func testInitFromRawValue() {

    }

    func testConfigurationShouldMuteAlerts() {

    }

    func testPublishing() {

    }

    func testCheck() {

    }

    func testShouldMuteAlertIssuedFromNow() {

    }

    func testProcessAlert() {

    }
}
