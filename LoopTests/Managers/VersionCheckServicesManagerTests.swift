//
//  VersionCheckerManagerTests.swift
//  LoopTests
//
//  Created by Rick Pasetto on 9/10/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit
@testable import Loop

class VersionCheckerManagerTests: XCTestCase {
    enum MockError: Error { case nothing }

    class MockVersionChecker: VersionChecker {
        var mockResult: Result<VersionUpdate?, Error> = .success(.default)
        func checkVersion(bundleIdentifier: String, currentVersion: String, completion: @escaping (Result<VersionUpdate?, Error>) -> Void) {
            completion(mockResult)
        }
        convenience init() { self.init(rawState: [:])! }
        static var localizedTitle = "MockVersionChecker"
        static var serviceIdentifier = "MockVersionChecker"
        var serviceDelegate: ServiceDelegate?
        required init?(rawState: RawStateValue) { }
        var rawState: RawStateValue = [:]
        var isOnboarded: Bool = false
    }
    
    class MockAlertIssuer: AlertIssuer {
        var issued: Alert?
        var retracted: Alert.Identifier?
        var alertExpectation: XCTestExpectation?

        func issueAlert(_ alert: Alert) {
            issued = alert
            alertExpectation?.fulfill()
        }
        
        func retractAlert(identifier: Alert.Identifier) {
            retracted = identifier
        }
    }
    
    var versionCheckerManager: VersionCheckerManager!
    var mockVersionChecker: MockVersionChecker!
    var mockAlertIssuer: MockAlertIssuer!

    override func setUp() {
        mockAlertIssuer = MockAlertIssuer()
        versionCheckerManager = VersionCheckerManager(alertIssuer: mockAlertIssuer)
        mockVersionChecker = MockVersionChecker()
        versionCheckerManager.addService(mockVersionChecker)
    }
    
    func getVersion(fn: String = #function) -> VersionUpdate? {
        let e = expectation(description: fn)
        var result: VersionUpdate?
        versionCheckerManager.checkVersion {
            result = $0
            e.fulfill()
        }
        wait(for: [e], timeout: 1.0)
        return result
    }
    
    func testVersionCheckOneService() throws {
        XCTAssertEqual(VersionUpdate.none, getVersion())
        mockVersionChecker.mockResult = .success(.required)
        XCTAssertEqual(.required, getVersion())
    }
    
    func testVersionCheckOneServiceError() throws {
        // Error doesn't really do anything but log
        mockVersionChecker.mockResult = .failure(MockError.nothing)
        XCTAssertEqual(VersionUpdate.none, getVersion())
    }
    
    func testVersionCheckMultipleServices() throws {
        let anotherService = MockVersionChecker()
        versionCheckerManager.addService(anotherService)
        XCTAssertEqual(VersionUpdate.none, getVersion())
        anotherService.mockResult = .success(.required)
        XCTAssertEqual(.required, getVersion())
        mockVersionChecker.mockResult = .success(.recommended)
        XCTAssertEqual(.required, getVersion())
    }
    
    func testNoAlertForNormalUpdate() {
        mockVersionChecker.mockResult = .success(.available)
        mockAlertIssuer.alertExpectation = expectation(description: #function)
        mockAlertIssuer.alertExpectation?.isInverted = true
        versionCheckerManager.performCheck()
        wait(for: [mockAlertIssuer.alertExpectation!], timeout: 1.0)
    }
    
    func testAlertForRecommendedUpdate() {
        mockVersionChecker.mockResult = .success(.recommended)
        mockAlertIssuer.alertExpectation = expectation(description: #function)
        versionCheckerManager.performCheck()
        wait(for: [mockAlertIssuer.alertExpectation!], timeout: 1.0)
    }
}
