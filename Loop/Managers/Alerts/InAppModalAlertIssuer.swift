//
//  InAppModalAlertIssuer.swift
//  LoopKit
//
//  Created by Rick Pasetto on 4/9/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit

public class InAppModalAlertIssuer: AlertIssuer {

    private weak var alertPresenter: AlertPresenter?
    private weak var alertManagerResponder: AlertManagerResponder?

    private var alertsPresented: [Alert.Identifier: (UIAlertController, Alert)] = [:]
    private var alertsPending: [Alert.Identifier: (Timer, Alert)] = [:]

    typealias ActionFactoryFunction = (String?, UIAlertAction.Style, ((UIAlertAction) -> Void)?) -> UIAlertAction
    private let newActionFunc: ActionFactoryFunction
    
    typealias TimerFactoryFunction = (TimeInterval, Bool, (() -> Void)?) -> Timer
    private let newTimerFunc: TimerFactoryFunction

    typealias TimerAtNextDateMatchingFactoryFunction = (DateComponents, Bool, (() -> Void)?) -> Timer?
    private let newTimerAtNextDateMatchingFunc: TimerAtNextDateMatchingFactoryFunction

    private let soundPlayer: AlertSoundPlayer

    init(alertPresenter: AlertPresenter?,
         alertManagerResponder: AlertManagerResponder,
         soundPlayer: AlertSoundPlayer = DeviceAVSoundPlayer(),
         newActionFunc: @escaping ActionFactoryFunction = UIAlertAction.init,
         newTimerFunc: TimerFactoryFunction? = nil,
         newTimerAtNextDateMatchingFunc: TimerAtNextDateMatchingFactoryFunction? = nil,
         now: @escaping () -> Date = Date.init)
    {
        self.alertPresenter = alertPresenter
        self.alertManagerResponder = alertManagerResponder
        self.soundPlayer = soundPlayer
        self.newActionFunc = newActionFunc
        self.newTimerFunc = newTimerFunc ?? { timeInterval, repeats, block in
            return Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: repeats) { _ in block?() }
        }
        self.newTimerAtNextDateMatchingFunc = newTimerAtNextDateMatchingFunc ?? { dateComponents, repeats, block in
            func next() -> Date? {
                return Calendar.current.nextDate(after: now(), matching: dateComponents, matchingPolicy: .nextTime)
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
            RunLoop.current.add(timer, forMode: .default)
            return timer
        }
    }

    public func issueAlert(_ alert: Alert) {
        switch alert.trigger {
        case .immediate:
            show(alert: alert)
        case .delayed(let interval):
            schedule(alert: alert, repeats: false) { [weak self] in
                self?.newTimerFunc(interval, $0, $1)
            }
        case .repeating(let interval):
            schedule(alert: alert, repeats: true) { [weak self] in
                self?.newTimerFunc(interval, $0, $1)
            }
        case .nextDate(let matching):
            schedule(alert: alert, repeats: false) { [weak self] in
                self?.newTimerAtNextDateMatchingFunc(matching, $0, $1)
            }
            break
        case .nextDateRepeating(let matching):
            schedule(alert: alert, repeats: true) { [weak self] in
                self?.newTimerAtNextDateMatchingFunc(matching, $0, $1)
            }
            break
        }
    }
    
    public func retractAlert(identifier: Alert.Identifier) {
        DispatchQueue.main.async {
            self.removePendingAlert(identifier: identifier)
            self.removePresentedAlert(identifier: identifier)
        }
    }

    func removePresentedAlert(identifier: Alert.Identifier, completion: (() -> Void)? = nil) {
        guard let alertPresented = alertsPresented[identifier] else {
            completion?()
            return
        }
        alertPresenter?.dismissAlert(alertPresented.0, animated: true, completion: completion)
        clearPresentedAlert(identifier: identifier)
    }

    func removePendingAlert(identifier: Alert.Identifier) {
        guard let alertPending = alertsPending[identifier] else { return }
        alertPending.0.invalidate()
        clearPendingAlert(identifier: identifier)
    }
}

/// For testing only
extension InAppModalAlertIssuer {
    func getPendingAlerts() -> [Alert.Identifier: (Timer, Alert)] {
        return alertsPending
    }
}

/// Private functions
extension InAppModalAlertIssuer {

    private func schedule(alert: Alert, repeats: Bool, newTimer: @escaping (Bool, @escaping () -> Void) -> Timer?) {
        guard alert.foregroundContent != nil else {
            return
        }
        DispatchQueue.main.async {
            if self.isAlertPending(identifier: alert.identifier) {
                return
            }
            if let timer = newTimer(repeats, { [weak self] in
                self?.show(alert: alert)
                if !repeats {
                    self?.clearPendingAlert(identifier: alert.identifier)
                }
            }) {
                self.addPendingAlert(alert: alert, timer: timer)
            }
        }
    }
    
    private func show(alert: Alert) {
        guard let content = alert.foregroundContent else {
            return
        }
        DispatchQueue.main.async {
            if self.isAlertPresented(identifier: alert.identifier) {
                return
            }
            let alertController = self.constructAlert(title: content.title,
                                                      message: content.body,
                                                      action: content.acknowledgeActionButtonLabel,
                                                      isCritical: alert.interruptionLevel == .critical) { [weak self] in
                // the completion is called after the alert is acknowledged
                self?.clearPresentedAlert(identifier: alert.identifier)
                self?.alertManagerResponder?.acknowledgeAlert(identifier: alert.identifier)
            }
            self.alertPresenter?.present(alertController, animated: true) { [weak self] in
                // the completion is called after the alert is presented
                self?.playSound(for: alert)
                self?.addPresentedAlert(alert: alert, controller: alertController)
            }
        }
    }
    
    private func addPendingAlert(alert: Alert, timer: Timer) {
        dispatchPrecondition(condition: .onQueue(.main))
        alertsPending[alert.identifier] = (timer, alert)
    }

    private func addPresentedAlert(alert: Alert, controller: UIAlertController) {
        dispatchPrecondition(condition: .onQueue(.main))
        alertsPresented[alert.identifier] = (controller, alert)
    }
    
    private func clearPendingAlert(identifier: Alert.Identifier) {
        dispatchPrecondition(condition: .onQueue(.main))
        alertsPending[identifier] = nil
    }

    private func clearPresentedAlert(identifier: Alert.Identifier) {
        dispatchPrecondition(condition: .onQueue(.main))
        alertsPresented[identifier] = nil
    }

    private func isAlertPending(identifier: Alert.Identifier) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return alertsPending.index(forKey: identifier) != nil
    }
    
    private func isAlertPresented(identifier: Alert.Identifier) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return alertsPresented.index(forKey: identifier) != nil
    }

    private func constructAlert(title: String, message: String, action: String, isCritical: Bool, acknowledgeCompletion: @escaping () -> Void) -> UIAlertController {
        dispatchPrecondition(condition: .onQueue(.main))
        // For now, this is a simple alert with an "OK" button
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(newActionFunc(action, .default, { _ in acknowledgeCompletion() }))
        return alertController
    }

    private func playSound(for alert: Alert) {
        guard let sound = alert.sound else { return }
        switch sound {
        case .vibrate:
            soundPlayer.vibrate()
        case .silence:
            break
        default:
            // Assuming in-app alerts should also vibrate.  That way, if the user has "silent mode" on, they still get
            // some kind of haptic feedback
            soundPlayer.vibrate()
            guard let url = AlertManager.soundURL(for: alert) else { return }
            soundPlayer.play(url: url)
        }
    }
}
