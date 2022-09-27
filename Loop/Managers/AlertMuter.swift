//
//  AlertMuter.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2022-09-14.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import LoopKit

public class AlertMuter: ObservableObject {
    struct Configuration: Equatable, RawRepresentable {
        typealias RawValue = [String: Any]

        enum ConfigurationKey: String {
            case enabled
            case duration
            case startTime
        }

        init?(rawValue: [String : Any]) {
            guard let enabled = rawValue[ConfigurationKey.enabled.rawValue] as? Bool,
                  let duration = rawValue[ConfigurationKey.duration.rawValue] as? TimeInterval
            else { return nil }

            self.enabled = enabled
            self.duration = duration
            self.startTime = rawValue[ConfigurationKey.startTime.rawValue] as? Date
        }

        var rawValue: [String : Any] {
            var rawValue: [String : Any] = [:]
            rawValue[ConfigurationKey.enabled.rawValue] = enabled
            rawValue[ConfigurationKey.duration.rawValue] = duration
            rawValue[ConfigurationKey.startTime.rawValue] = startTime
            return rawValue
        }

        var enabled: Bool {
            didSet {
                guard enabled else { return }
                startTime = Date()
            }
        }
        var duration: TimeInterval
        private(set) var startTime: Date?

        init(enabled: Bool, duration: TimeInterval = AlertMuter.allowedDurations[0]) {
            self.enabled = enabled
            self.duration = duration
            self.startTime = enabled ? Date() : nil
        }

        var shouldMuteAlerts: Bool {
            shouldMuteAlertIssuedFromNow()
        }

        func shouldMuteAlertIssuedFromNow(_ fromNow: TimeInterval = 0) -> Bool {
            guard fromNow >= 0 else { return false }

            guard enabled else { return false }

            guard let startTime = startTime else { return false }

            let alertTriggerTime = Date().advanced(by: fromNow)
            let endMutingTime = startTime.addingTimeInterval(duration)
            guard alertTriggerTime < endMutingTime
            else { return false }

            return true
        }
    }

    @Published var configuration: Configuration

    private lazy var cancellables = Set<AnyCancellable>()

    static var allowedDurations: [TimeInterval] { [.minutes(30), .hours(1), .hours(2), .hours(4)] }

    init(configuration: Configuration = Configuration(enabled: false)) {
        self.configuration = configuration

        // This could be off by ~5 minutes.
        NotificationCenter.default.publisher(for: .LoopCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.check()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.check()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.check()
            }
            .store(in: &cancellables)
    }

    convenience init(enabled: Bool = false, duration: TimeInterval = AlertMuter.allowedDurations[0]) {
        self.init(configuration: Configuration(enabled: enabled, duration: duration))
    }

    func check() {
        // this is enabled by user action, so only need to check if the duration has elapsed and then disable
        guard !configuration.shouldMuteAlerts,
              configuration.enabled
        else { return }

        configuration.enabled = false
    }

    func shouldMuteAlertIssuedFromNow(_ fromNow: TimeInterval = 0) -> Bool {
        check()
        return configuration.shouldMuteAlertIssuedFromNow(fromNow)
    }

    private func shouldMuteAlert(_ alert: LoopKit.Alert, issuedDate: Date) -> Bool {
        switch alert.trigger {
        case .immediate:
            return shouldMuteAlertIssuedFromNow()
        case .delayed(let interval), .repeating(let interval):
            let triggerInterval = (issuedDate + interval).timeIntervalSinceNow
            return shouldMuteAlertIssuedFromNow(triggerInterval)
        }
    }

    func processAlert(_ alert: LoopKit.Alert, issuedDate: Date) -> LoopKit.Alert {
        guard alert.sound != .vibrate else { return alert }

        guard shouldMuteAlert(alert, issuedDate: issuedDate) else { return alert }

        return LoopKit.Alert(identifier: alert.identifier,
                             foregroundContent: alert.foregroundContent,
                             backgroundContent: alert.backgroundContent,
                             trigger: alert.trigger,
                             interruptionLevel: alert.interruptionLevel,
                             sound: .vibrate,
                             metadata: alert.metadata)
    }
}
