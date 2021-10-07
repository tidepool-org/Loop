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

    class MockVersionCheckService: VersionCheckService {
        var mockResult: Result<VersionUpdate?, Error> = .success(.noneNeeded)
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
        versionCheckServicesManager.checkVersion(currentVersion: "") {
            result = $0
            e.fulfill()
        }
        wait(for: [e], timeout: 1.0)
        return result
    }
    
    func testVersionCheckOneService() throws {
        XCTAssertEqual(.noneNeeded, getVersion())
        mockVersionCheckService.mockResult = .success(.criticalNeeded)
        XCTAssertEqual(.criticalNeeded, getVersion())
    }
    
    func testVersionCheckOneServiceError() throws {
        // Error doesn't really do anything but log
        mockVersionCheckService.mockResult = .failure(MockError.nothing)
        XCTAssertEqual(.noneNeeded, getVersion())
    }
    
    func testVersionCheckMultipleServices() throws {
        let anotherService = MockVersionCheckService()
        versionCheckServicesManager.addService(anotherService)
        XCTAssertEqual(.noneNeeded, getVersion())
        anotherService.mockResult = .success(.criticalNeeded)
        XCTAssertEqual(.criticalNeeded, getVersion())
        mockVersionCheckService.mockResult = .success(.supportedNeeded)
        XCTAssertEqual(.criticalNeeded, getVersion())
    }
        
    @available(iOS 15.0.0, *)
    func testVersionCheckOneServiceAsync() async throws {
        var versionUpdate = await versionCheckServicesManager.checkVersion(currentVersion: "")
        XCTAssertEqual(.noneNeeded, versionUpdate)
        mockVersionCheckService.mockResult = .success(.criticalNeeded)
        versionUpdate = await versionCheckServicesManager.checkVersion(currentVersion: "")
        XCTAssertEqual(.criticalNeeded, versionUpdate)
    }
    
    enum MockError: Error { case nothing }
    @available(iOS 15.0.0, *)
    func testVersionCheckOneServiceErrorAsync() async throws {
        // Error doesn't really do anything but log
        mockVersionCheckService.mockResult = .failure(MockError.nothing)
        let versionUpdate = await versionCheckServicesManager.checkVersion(currentVersion: "")
        XCTAssertEqual(.noneNeeded, versionUpdate)
    }

    @available(iOS 15.0.0, *)
    func testVersionCheckMultipleServicesAsync() async throws {
        let anotherService = MockVersionCheckService()
        versionCheckServicesManager.addService(anotherService)
        var versionUpdate = await versionCheckServicesManager.checkVersion(currentVersion: "")
        XCTAssertEqual(.noneNeeded, versionUpdate)
        anotherService.mockResult = .success(.criticalNeeded)
        versionUpdate = await versionCheckServicesManager.checkVersion(currentVersion: "")
        XCTAssertEqual(.criticalNeeded, versionUpdate)
        mockVersionCheckService.mockResult = .success(.supportedNeeded)
        versionUpdate = await versionCheckServicesManager.checkVersion(currentVersion: "")
        XCTAssertEqual(.criticalNeeded, versionUpdate)
    }
    
    func testNoAlertForNormalUpdate() {
        mockVersionCheckService.mockResult = .success(.updateNeeded)
        mockAlertIssuer.alertExpectation = expectation(description: #function)
        mockAlertIssuer.alertExpectation?.isInverted = true
        versionCheckServicesManager.performCheck()
        wait(for: [mockAlertIssuer.alertExpectation!], timeout: 1.0)
    }
    
    func testAlertForRecommendedUpdate() {
        mockVersionCheckService.mockResult = .success(.supportedNeeded)
        mockAlertIssuer.alertExpectation = expectation(description: #function)
        versionCheckServicesManager.performCheck()
        wait(for: [mockAlertIssuer.alertExpectation!], timeout: 1.0)
    }
}
