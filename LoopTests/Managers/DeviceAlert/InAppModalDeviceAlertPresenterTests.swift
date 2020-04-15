//
//  InAppModalDeviceAlertPresenterTests.swift
//  LoopTests
//
//  Created by Rick Pasetto on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import XCTest
@testable import Loop

class InAppModalDeviceAlertPresenterTests: XCTestCase {

    class MockAlertManagerResponder: DeviceAlertManagerResponder {
        var identifierAcknowledged: DeviceAlert.Identifier?
        func acknowledgeDeviceAlert(identifier: DeviceAlert.Identifier) {
            identifierAcknowledged = identifier
        }
    }
    
    class MockViewController: UIViewController {
        var viewControllerPresented: UIViewController?
        override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
            viewControllerPresented = viewControllerToPresent
            completion?()
        }
    }

    let mockIdentifier = DeviceAlert.Identifier(managerIdentifier: "foo", typeIdentifier: "bar")
    let mockForegroundContent = DeviceAlert.Content(title: "FOREGROUND", body: "foreground", acknowledgeActionButtonLabel: "")
    let mockBackgroundContent = DeviceAlert.Content(title: "BACKGROUND", body: "background", acknowledgeActionButtonLabel: "")
    var mockAlertManagerResponder: MockAlertManagerResponder!
    var mockViewController: MockViewController!
    var inAppModalDeviceAlertPresenter: InAppModalDeviceAlertPresenter!
    
    override func setUp() {
        mockAlertManagerResponder = MockAlertManagerResponder()
        mockViewController = MockViewController()
        inAppModalDeviceAlertPresenter = InAppModalDeviceAlertPresenter(rootViewController: mockViewController, deviceAlertManagerResponder: mockAlertManagerResponder)
    }

    func testIssueImmediateAlert() {
        let alert = DeviceAlert(identifier: mockIdentifier, foregroundContent: mockForegroundContent, backgroundContent: mockBackgroundContent, trigger: .immediate)
        inAppModalDeviceAlertPresenter.issueAlert(alert)
        waitOnMain {
            let alertController = mockViewController.viewControllerPresented as? UIAlertController
            XCTAssertNotNil(alertController)
            XCTAssertEqual("FOREGROUND", alertController?.title)
        }
    }
    
    func waitOnMain(completion: ()->Void) {
        let exp = expectation(description: "waitOnMain")
        DispatchQueue.main.async {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        completion()
    }
}
