//
//  VersionCheckServicesManagerTests.swift
//  LoopTests
//
//  Created by Rick Pasetto on 9/10/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit
@testable import Loop

class VersionCheckServicesManagerTests: XCTestCase {
    enum MockError: Error { case nothing }

    class MockVersionCheckService: VersionCheckService {
        var mockResult: Result<VersionUpdate?, Error> = .success(.default)
        func checkVersion(bundleIdentifier: String, currentVersion: String, completion: @escaping (Result<VersionUpdate?, Error>) -> Void) {
            completion(mockResult)
        }
        convenience init() { self.init(rawState: [:])! }
        static var localizedTitle = "MockVersionCheckService"
        static var serviceIdentifier = "MockVersionCheckService"
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
    
    var versionCheckServicesManager: VersionCheckServicesManager!
    var mockVersionCheckService: MockVersionCheckService!
    var mockAlertIssuer: MockAlertIssuer!

    override func setUp() {
        mockAlertIssuer = MockAlertIssuer()
        versionCheckServicesManager = VersionCheckServicesManager(alertIssuer: mockAlertIssuer)
        mockVersionCheckService = MockVersionCheckService()
        versionCheckServicesManager.addService(mockVersionCheckService)
    }
    
    func getVersion(fn: String = #function) -> VersionUpdate? {
        let e = expectation(description: fn)
        var result: VersionUpdate?
        versionCheckServicesManager.checkVersion {
            result = $0
            e.fulfill()
        }
        wait(for: [e], timeout: 1.0)
        return result
    }
    
    func testVersionCheckOneService() throws {
        XCTAssertEqual(VersionUpdate.none, getVersion())
        mockVersionCheckService.mockResult = .success(.required)
        XCTAssertEqual(.required, getVersion())
    }
    
    func testVersionCheckOneServiceError() throws {
        // Error doesn't really do anything but log
        mockVersionCheckService.mockResult = .failure(MockError.nothing)
        XCTAssertEqual(VersionUpdate.none, getVersion())
    }
    
    func testVersionCheckMultipleServices() throws {
        let anotherService = MockVersionCheckService()
        versionCheckServicesManager.addService(anotherService)
        XCTAssertEqual(VersionUpdate.none, getVersion())
        anotherService.mockResult = .success(.required)
        XCTAssertEqual(.required, getVersion())
        mockVersionCheckService.mockResult = .success(.recommended)
        XCTAssertEqual(.required, getVersion())
    }
    
    func testNoAlertForNormalUpdate() {
        mockVersionCheckService.mockResult = .success(.available)
        mockAlertIssuer.alertExpectation = expectation(description: #function)
        mockAlertIssuer.alertExpectation?.isInverted = true
        versionCheckServicesManager.performCheck()
        wait(for: [mockAlertIssuer.alertExpectation!], timeout: 1.0)
    }
    
    func testAlertForRecommendedUpdate() {
        mockVersionCheckService.mockResult = .success(.recommended)
        mockAlertIssuer.alertExpectation = expectation(description: #function)
        versionCheckServicesManager.performCheck()
        wait(for: [mockAlertIssuer.alertExpectation!], timeout: 1.0)
    }
}
