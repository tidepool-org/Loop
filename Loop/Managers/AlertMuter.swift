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
            case duration
            case startTime
        }

        init?(rawValue: [String : Any]) {
            guard let duration = rawValue[ConfigurationKey.duration.rawValue] as? TimeInterval
            else { return nil }

            self.duration = duration
            self.startTime = rawValue[ConfigurationKey.startTime.rawValue] as? Date
        }

        var rawValue: [String : Any] {
            var rawValue: [String : Any] = [:]
            rawValue[ConfigurationKey.duration.rawValue] = duration
            rawValue[ConfigurationKey.startTime.rawValue] = startTime
            return rawValue
        }

        var duration: TimeInterval

        var startTime: Date?

        var enabled: Bool {
            guard let mutingEndTime = mutingEndTime else { return false }
            return mutingEndTime >= Date()
        }

        var mutingEndTime: Date? {
            startTime?.addingTimeInterval(duration)
        }

        init(startTime: Date? = nil, duration: TimeInterval = AlertMuter.allowedDurations[0]) {
            self.duration = duration
            self.startTime = startTime
        }

        var shouldMuteAlerts: Bool {
            shouldMuteAlert()
        }

        func shouldMuteAlert(scheduledAt timeFromNow: TimeInterval = 0, now: Date = Date()) -> Bool {
            guard timeFromNow >= 0 else { return false }

            guard let mutingEndTime = mutingEndTime else { return false }

            let alertTriggerTime = now.advanced(by: timeFromNow)
            guard alertTriggerTime < mutingEndTime
            else { return false }

            return true
        }
    }

    @Published var configuration: Configuration

    private lazy var cancellables = Set<AnyCancellable>()

    static var allowedDurations: [TimeInterval] { [.seconds(5), .minutes(30), .hours(1), .hours(2), .hours(4)] }

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration

        // Checks triggered by looping may disable the muting of alert up to an additional loop interval (currently 5 minutes) after the actual duration
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

    convenience init(startTime: Date? = nil, duration: TimeInterval = AlertMuter.allowedDurations[0]) {
        self.init(configuration: Configuration(startTime: startTime, duration: duration))
    }

    func check(_ now: Date = Date()) {
        // this is enabled by user action, so only need to check if the duration has elapsed and remove the startTime
        guard let startTime = configuration.startTime,
              startTime.addingTimeInterval(configuration.duration) < now
        else { return }

        configuration.startTime = nil
    }

    func shouldMuteAlert(scheduledAt timeFromNow: TimeInterval = 0) -> Bool {
        return configuration.shouldMuteAlert(scheduledAt: timeFromNow)
    }

    private func shouldMuteAlert(_ alert: LoopKit.Alert, issuedDate: Date) -> Bool {
        switch alert.trigger {
        case .immediate:
            return shouldMuteAlert()
        case .delayed(let interval), .repeating(let interval):
            let triggerInterval = (issuedDate + interval).timeIntervalSinceNow
            return shouldMuteAlert(scheduledAt: triggerInterval)
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
