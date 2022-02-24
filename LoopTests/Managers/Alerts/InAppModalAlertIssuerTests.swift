//
//  InAppModalAlertIssuerTests.swift
//  LoopTests
//
//  Created by Rick Pasetto on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import XCTest
@testable import Loop

class InAppModalAlertIssuerTests: XCTestCase {
    
    class MockAlertAction: UIAlertAction {
        typealias Handler = ((UIAlertAction) -> Void)
        var handler: Handler?
        var mockTitle: String?
        var mockStyle: Style
        convenience init(title: String?, style: Style, handler: Handler?) {
            self.init()
            
            mockTitle = title
            mockStyle = style
            self.handler = handler
        }
        override init() {
            mockStyle = .default
            super.init()
        }
        func callHandler() {
            handler?(self)
        }
    }
    
    class MockAlertManagerResponder: AlertManagerResponder {
        var identifierAcknowledged: Alert.Identifier?
        func acknowledgeAlert(identifier: Alert.Identifier) {
            identifierAcknowledged = identifier
        }
    }
    
    class MockViewController: UIViewController, AlertPresenter {
        var viewControllerPresented: UIViewController?
        var alertDismissed: UIAlertController?
        var autoComplete = true
        var completion: (() -> Void)?
        override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
            viewControllerPresented = viewControllerToPresent
            if autoComplete {
                completion?()
            } else {
                self.completion = completion
            }
        }
        func dismissTopMost(animated: Bool, completion: (() -> Void)?) {
            if autoComplete {
                completion?()
            } else {
                self.completion = completion
            }
        }
        func dismissAlert(_ alertToDismiss: UIAlertController, animated: Bool, completion: (() -> Void)?) {
            alertDismissed = alertToDismiss
            if autoComplete {
                completion?()
            } else {
                self.completion = completion
            }
        }
        func callCompletion() {
            completion?()
        }
    }

    class MockSoundPlayer: AlertSoundPlayer {
        var vibrateCalled = false
        func vibrate() {
            vibrateCalled = true
        }
        var urlPlayed: URL?
        func play(url: URL) {
            urlPlayed = url
        }
        var stopAllCalled = false
        func stopAll() {
            stopAllCalled = true
        }
    }
    
    static let managerIdentifier = "managerIdentifier"
    let alertIdentifier = Alert.Identifier(managerIdentifier: managerIdentifier, alertIdentifier: "bar")
    let foregroundContent = Alert.Content(title: "FOREGROUND", body: "foreground", acknowledgeActionButtonLabel: "")
    let backgroundContent = Alert.Content(title: "BACKGROUND", body: "background", acknowledgeActionButtonLabel: "")
    
    var mockTimer: Timer?
    var mockTimerTimeInterval: TimeInterval?
    var mockTimerRepeats: Bool?
    var mockDateMatchingTimer: Timer?
    var mockDateMatchingTimerComponents: DateComponents?
    var mockDateMatchingTimerRepeats: Bool?
    var mockAlertManagerResponder: MockAlertManagerResponder!
    var mockViewController: MockViewController!
    var mockSoundPlayer: MockSoundPlayer!
    var inAppModalAlertIssuer: InAppModalAlertIssuer!
    var now: ()->Date = Date.init
    
    override func setUpWithError() throws {
        now = Date.init
        mockAlertManagerResponder = MockAlertManagerResponder()
        mockViewController = MockViewController()
        mockSoundPlayer = MockSoundPlayer()
        
        let newTimerFunc: InAppModalAlertIssuer.TimerFactoryFunction = { timeInterval, repeats, block in
            let timer = Timer(timeInterval: timeInterval, repeats: repeats) { _ in block?() }
            self.mockTimer = timer
            self.mockTimerTimeInterval = timeInterval
            self.mockTimerRepeats = repeats
            return timer
        }
        let newTimerAtNextDateMatchingFunc: InAppModalAlertIssuer.TimerAtNextDateMatchingFactoryFunction = { dateComponents, repeats, block in
            func next() -> Date? {
                return Calendar.current.nextDate(after: self.now(), matching: dateComponents, matchingPolicy: .nextTime)
            }
            guard let nextDate = next() else {
                return nil
            }
            let timer = Timer(fire: nextDate, interval: 0, repeats: repeats) { t in
                if repeats, let fireDate = next() {
                    // Apparently, if you make a repeating timer, setting the fire date again will reschedule it
                    // for that date.  Cool.
                    t.fireDate = fireDate
                }
                block?()
            }
            self.mockDateMatchingTimer = timer
            self.mockDateMatchingTimerComponents = dateComponents
            self.mockDateMatchingTimerRepeats = repeats
            return timer
        }
        inAppModalAlertIssuer = InAppModalAlertIssuer(alertPresenter: mockViewController,
                                                      alertManagerResponder: mockAlertManagerResponder,
                                                      soundPlayer: mockSoundPlayer,
                                                      newActionFunc: MockAlertAction.init,
                                                      newTimerFunc: newTimerFunc,
                                                      newTimerAtNextDateMatchingFunc: newTimerAtNextDateMatchingFunc
        )
    }
    
    func testIssueImmediateAlert() {
        let alert = Alert(identifier: alertIdentifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate)
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        let alertController = mockViewController.viewControllerPresented as? UIAlertController
        XCTAssertNotNil(alertController)
        XCTAssertEqual("FOREGROUND", alertController?.title)
        XCTAssertEqual(nil, mockSoundPlayer.urlPlayed?.absoluteString)
        XCTAssertFalse(mockSoundPlayer.vibrateCalled)
    }
    
    func testIssueImmediateAlertWithSound() {
        let soundName = "soundName"
        let alert = Alert(identifier: alertIdentifier,
                          foregroundContent: foregroundContent,
                          backgroundContent: backgroundContent,
                          trigger: .immediate,
                          sound: .sound(name: soundName))
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        let alertController = mockViewController.viewControllerPresented as? UIAlertController
        XCTAssertNotNil(alertController)
        XCTAssertEqual("FOREGROUND", alertController?.title)
        XCTAssertEqual("\(InAppModalAlertIssuerTests.managerIdentifier)-\(soundName)", mockSoundPlayer.urlPlayed?.lastPathComponent)
        XCTAssertTrue(mockSoundPlayer.vibrateCalled)
    }
    
    func testIssueImmediateAlertWithVibrate() {
        let alert = Alert(identifier: alertIdentifier,
                          foregroundContent: foregroundContent,
                          backgroundContent: backgroundContent,
                          trigger: .immediate,
                          sound: .vibrate)
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        let alertController = mockViewController.viewControllerPresented as? UIAlertController
        XCTAssertNotNil(alertController)
        XCTAssertEqual("FOREGROUND", alertController?.title)
        XCTAssertEqual(nil, mockSoundPlayer.urlPlayed?.absoluteString)
        XCTAssertTrue(mockSoundPlayer.vibrateCalled)
    }
    
    func testIssueImmediateAlertWithSilence() {
        let alert = Alert(identifier: alertIdentifier,
                          foregroundContent: foregroundContent,
                          backgroundContent: backgroundContent,
                          trigger: .immediate,
                          sound: .silence)
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        let alertController = mockViewController.viewControllerPresented as? UIAlertController
        XCTAssertNotNil(alertController)
        XCTAssertEqual("FOREGROUND", alertController?.title)
        XCTAssertEqual(nil, mockSoundPlayer.urlPlayed?.absoluteString)
        XCTAssertFalse(mockSoundPlayer.vibrateCalled)
    }
    
    func testRemoveImmediateAlert() {
        let alert = Alert(identifier: alertIdentifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate)
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        let alertControllerPresented = mockViewController.viewControllerPresented as? UIAlertController
        XCTAssertNotNil(alertControllerPresented)

        var dismissed = false
        inAppModalAlertIssuer.removePresentedAlert(identifier: alert.identifier) {
            dismissed = true
        }

        waitOnMain()
        let alertDimissed = mockViewController.alertDismissed
        XCTAssertNotNil(alertDimissed)
        XCTAssertTrue(dismissed)
    }
    
    func testIssueImmediateAlertTwiceOnlyOneShows() {
        let alert = Alert(identifier: alertIdentifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger:
            .immediate)
        mockViewController.autoComplete = false
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        mockViewController.viewControllerPresented = nil
        inAppModalAlertIssuer.issueAlert(alert)
        XCTAssertNil(mockViewController.viewControllerPresented)
    }
    
    func testIssueImmediateAlertWithoutForegroundContentDoesNothing() {
        let alert = Alert(identifier: alertIdentifier, foregroundContent: nil, backgroundContent: backgroundContent, trigger: .immediate)
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        XCTAssertNil(mockViewController.viewControllerPresented)
    }
    
    func testIssueImmediateAlertAcknowledgement() {
        let alert = Alert(identifier: alertIdentifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .immediate)
        inAppModalAlertIssuer.issueAlert(alert)
        waitOnMain()
        let action = (mockViewController.viewControllerPresented as? UIAlertController)?.actions[0] as? MockAlertAction
        XCTAssertNotNil(action)
        XCTAssertNil(mockAlertManagerResponder.identifierAcknowledged)
        action?.callHandler()
        XCTAssertEqual(alertIdentifier, mockAlertManagerResponder.identifierAcknowledged)
    }
    
    func testIssueDelayedAlert() throws {
        let alert = Alert(identifier: alertIdentifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .delayed(interval: 0.1))
        mockViewController.autoComplete = false
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        // Timer should be created but won't fire yet
        XCTAssertNil(mockViewController.viewControllerPresented)
        XCTAssertEqual(0.1, mockTimerTimeInterval)
        XCTAssert(mockTimerRepeats == false)
        XCTAssertFalse(inAppModalAlertIssuer.getPendingAlerts().isEmpty)
        try XCTUnwrap(mockTimer).fire()
        
        waitOnMain()
        XCTAssertTrue(inAppModalAlertIssuer.getPendingAlerts().isEmpty)
        let alertController = mockViewController.viewControllerPresented as? UIAlertController
        XCTAssertNotNil(alertController)
        XCTAssertEqual("FOREGROUND", alertController?.title)
    }
    
    func testIssueDelayedAlertTwiceOnlyOneWorks() throws {
        let alert = Alert(identifier: alertIdentifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .delayed(interval: 0.1))
        mockViewController.autoComplete = false
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        guard let firstTimer = mockTimer else { XCTFail(); return }
        mockTimer = nil
        // This should not schedule another timer
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        XCTAssertNil(mockTimer)
        XCTAssertNil(mockViewController.viewControllerPresented)
        firstTimer.fire()
        
        waitOnMain()
        XCTAssertNil(mockTimer)
        XCTAssertNotNil(mockViewController.viewControllerPresented)
    }
    
    func testIssueDelayedAlertWithoutForegroundContentDoesNothing() throws {
        let alert = Alert(identifier: alertIdentifier, foregroundContent: nil, backgroundContent: backgroundContent, trigger: .delayed(interval: 0.1))
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        XCTAssertNil(mockViewController.viewControllerPresented)
    }
    
    func testRetractAlert() throws {
        let alert = Alert(identifier: alertIdentifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .delayed(interval: 0.1))
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        XCTAssert(mockTimer?.isValid == true)
        inAppModalAlertIssuer.retractAlert(identifier: alert.identifier)
        
        waitOnMain()
        XCTAssert(mockTimer?.isValid == false)
    }
    
    func testIssueRepeatingAlert() throws {
        let alert = Alert(identifier: alertIdentifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .repeating(repeatInterval: 0.1))
        mockViewController.autoComplete = false
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        // Timer should be created but won't fire yet
        XCTAssertNil(mockViewController.viewControllerPresented)
        XCTAssertEqual(0.1, mockTimerTimeInterval)
        XCTAssert(mockTimerRepeats == true)
        XCTAssertFalse(inAppModalAlertIssuer.getPendingAlerts().isEmpty)
        try XCTUnwrap(mockTimer).fire()
        
        waitOnMain()
        XCTAssertFalse(inAppModalAlertIssuer.getPendingAlerts().isEmpty)
        let alertController = mockViewController.viewControllerPresented as? UIAlertController
        XCTAssertNotNil(alertController)
        XCTAssertEqual("FOREGROUND", alertController?.title)
    }
    
    func testIssueNextDateMatchingAlert() throws {
        let noon = Alert.Trigger.TimeSpec(hourOfDay: 12, minuteOfHour: 0)
        let alert = Alert(identifier: alertIdentifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .nextDate(matching: noon))
        mockViewController.autoComplete = false
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        // Timer should be created but won't fire yet
        XCTAssertNil(mockViewController.viewControllerPresented)
        XCTAssertNil(mockTimer)
        XCTAssertNotNil(mockDateMatchingTimer)
        XCTAssertEqual(noon.dateComponents, mockDateMatchingTimerComponents)
        XCTAssertEqual(false, mockDateMatchingTimerRepeats)
        XCTAssertFalse(inAppModalAlertIssuer.getPendingAlerts().isEmpty)
        try XCTUnwrap(mockDateMatchingTimer).fire()

        waitOnMain()
        
        XCTAssertTrue(inAppModalAlertIssuer.getPendingAlerts().isEmpty)
        let alertController = mockViewController.viewControllerPresented as? UIAlertController
        XCTAssertNotNil(alertController)
        XCTAssertEqual("FOREGROUND", alertController?.title)
    }
    
    func testIssueNextDateMatchingRepeatingAlert() throws {
        let noon = Alert.Trigger.TimeSpec(hourOfDay: 12, minuteOfHour: 0)
        let alert = Alert(identifier: alertIdentifier, foregroundContent: foregroundContent, backgroundContent: backgroundContent, trigger: .nextDateRepeating(matching: noon))
        mockViewController.autoComplete = false
        inAppModalAlertIssuer.issueAlert(alert)
        
        waitOnMain()
        // Timer should be created but won't fire yet
        XCTAssertNil(mockViewController.viewControllerPresented)
        XCTAssertNil(mockTimer)
        XCTAssertNotNil(mockDateMatchingTimer)
        XCTAssertEqual(noon.dateComponents, mockDateMatchingTimerComponents)
        XCTAssertEqual(true, mockDateMatchingTimerRepeats)
        XCTAssertFalse(inAppModalAlertIssuer.getPendingAlerts().isEmpty)
        try XCTUnwrap(mockDateMatchingTimer).fire()

        waitOnMain()
        
        XCTAssertFalse(inAppModalAlertIssuer.getPendingAlerts().isEmpty)
        let alertController = mockViewController.viewControllerPresented as? UIAlertController
        XCTAssertNotNil(alertController)
        XCTAssertEqual("FOREGROUND", alertController?.title)
    }
    

}
