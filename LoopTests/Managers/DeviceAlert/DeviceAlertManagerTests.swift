//
//  DeviceAlertManagerTests.swift
//  LoopTests
//
//  Created by Rick Pasetto on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import XCTest
@testable import Loop

class DeviceAlertManagerTests: XCTestCase {
    
    class MockHandler: DeviceAlertPresenter {
        var issuedAlert: DeviceAlert?
        func issueAlert(_ alert: DeviceAlert) {
            issuedAlert = alert
        }
        var removedPendingAlertIdentifier: DeviceAlert.Identifier?
        func removePendingAlert(identifier: DeviceAlert.Identifier) {
            removedPendingAlertIdentifier = identifier
        }
        var removeDeliveredAlertIdentifier: DeviceAlert.Identifier?
        func removeDeliveredAlert(identifier: DeviceAlert.Identifier) {
            removeDeliveredAlertIdentifier = identifier
        }
    }
    
    class MockResponder: DeviceAlertResponder {
        var acknowledged: [DeviceAlert.TypeIdentifier: Bool] = [:]
        func acknowledgeAlert(typeIdentifier: DeviceAlert.TypeIdentifier) {
            acknowledged[typeIdentifier] = true
        }
    }
    
    static let mockManagerIdentifier = "mockManagerIdentifier"
    static let mockTypeIdentifier = "mockTypeIdentifier"
    let mockDeviceAlert = DeviceAlert(identifier: DeviceAlert.Identifier(managerIdentifier: mockManagerIdentifier, typeIdentifier: mockTypeIdentifier), foregroundContent: nil, backgroundContent: nil, trigger: .immediate)
    
    var mockHandler: MockHandler!
    var deviceAlertManager: DeviceAlertManager!
    var isInBackground = true
    
    override func setUp() {
        mockHandler = MockHandler()
        deviceAlertManager = DeviceAlertManager(rootViewController: UIViewController(),
                                                isAppInBackgroundFunc: { return self.isInBackground },
                                                handlers: [mockHandler])
    }
    
    func testIssueAlertOnHandlerCalled() {
        deviceAlertManager.issueAlert(mockDeviceAlert)
        XCTAssertEqual(mockDeviceAlert.identifier, mockHandler.issuedAlert?.identifier)
        XCTAssertNil(mockHandler.removeDeliveredAlertIdentifier)
        XCTAssertNil(mockHandler.removedPendingAlertIdentifier)
    }
    
    func testRemovePendingAlertOnHandlerCalled() {
        deviceAlertManager.removePendingAlert(identifier: mockDeviceAlert.identifier)
        XCTAssertNil(mockHandler.issuedAlert)
        XCTAssertEqual(mockDeviceAlert.identifier, mockHandler.removedPendingAlertIdentifier)
        XCTAssertNil(mockHandler.removeDeliveredAlertIdentifier)
    }
    
    func testRemoveDeliveredAlertOnHandlerCalled() {
        deviceAlertManager.removeDeliveredAlert(identifier: mockDeviceAlert.identifier)
        XCTAssertNil(mockHandler.issuedAlert)
        XCTAssertNil(mockHandler.removedPendingAlertIdentifier)
        XCTAssertEqual(mockDeviceAlert.identifier, mockHandler.removeDeliveredAlertIdentifier)
    }

    func testAlertResponderAcknowledged() {
        let responder = MockResponder()
        deviceAlertManager.addAlertResponder(key: Self.mockManagerIdentifier, alertResponder: responder)
        XCTAssertTrue(responder.acknowledged.isEmpty)
        deviceAlertManager.acknowledgeDeviceAlert(identifier: DeviceAlert.Identifier(managerIdentifier: Self.mockManagerIdentifier, typeIdentifier: Self.mockTypeIdentifier))
        XCTAssert(responder.acknowledged[Self.mockTypeIdentifier] == true)
    }
    
    func testAlertResponderNotAcknowledgedIfWrongManagerIdentifier() {
        let responder = MockResponder()
        deviceAlertManager.addAlertResponder(key: Self.mockManagerIdentifier, alertResponder: responder)
        XCTAssertTrue(responder.acknowledged.isEmpty)
        deviceAlertManager.acknowledgeDeviceAlert(identifier: DeviceAlert.Identifier(managerIdentifier: "foo", typeIdentifier: Self.mockTypeIdentifier))
        XCTAssertTrue(responder.acknowledged.isEmpty)
    }
    
    func testRemovedAlertResponderDoesntAcknowledge() {
        let responder = MockResponder()
        deviceAlertManager.addAlertResponder(key: Self.mockManagerIdentifier, alertResponder: responder)
        XCTAssertTrue(responder.acknowledged.isEmpty)
        deviceAlertManager.acknowledgeDeviceAlert(identifier: DeviceAlert.Identifier(managerIdentifier: Self.mockManagerIdentifier, typeIdentifier: Self.mockTypeIdentifier))
        XCTAssert(responder.acknowledged[Self.mockTypeIdentifier] == true)
        
        responder.acknowledged[DeviceAlertManagerTests.mockTypeIdentifier] = false
        deviceAlertManager.removeAlertResponder(key: DeviceAlertManagerTests.mockManagerIdentifier)
        deviceAlertManager.acknowledgeDeviceAlert(identifier: DeviceAlert.Identifier(managerIdentifier: Self.mockManagerIdentifier, typeIdentifier: Self.mockTypeIdentifier))
        XCTAssert(responder.acknowledged[Self.mockTypeIdentifier] == false)
    }
}
