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

        var isMuting: Bool {
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

        func remainingMuteDuration(from now: Date = Date()) -> TimeInterval? {
            startTime?.addingTimeInterval(duration).timeIntervalSince(now)
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

    @Published var configuration: Configuration {
        didSet {
            if oldValue != configuration {
                updateMutePeriondEndingWatcher()
            }
        }
    }

    private var mutePeriodEndingTimer: Timer?

    private lazy var cancellables = Set<AnyCancellable>()

    //TODO testing (remove 10 secs)
    static var allowedDurations: [TimeInterval] { [.seconds(10), .minutes(30), .hours(1), .hours(2), .hours(4)] }

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.updateMutePeriondEndingWatcher()
            }
            .store(in: &cancellables)
    }

    convenience init(startTime: Date? = nil, duration: TimeInterval = AlertMuter.allowedDurations[0]) {
        self.init(configuration: Configuration(startTime: startTime, duration: duration))
    }

    private func updateMutePeriondEndingWatcher(_ now: Date = Date()) {
        mutePeriodEndingTimer?.invalidate()

        guard let mutingEndTime = configuration.mutingEndTime else { return }

        guard mutingEndTime > now else {
            configuration.startTime = nil
            return
        }

        let timeInterval = mutingEndTime.timeIntervalSince(now)
        mutePeriodEndingTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.configuration.startTime = nil
        }
    }

    func shouldMuteAlert(scheduledAt timeFromNow: TimeInterval = 0) -> Bool {
        return configuration.shouldMuteAlert(scheduledAt: timeFromNow)
    }

    func shouldMuteAlert(_ alert: LoopKit.Alert, issuedDate: Date = Date()) -> Bool {
        switch alert.trigger {
        case .immediate:
            return shouldMuteAlert()
        case .delayed(let interval), .repeating(let interval):
            let triggerInterval = (issuedDate + interval).timeIntervalSinceNow
            return shouldMuteAlert(scheduledAt: triggerInterval)
        }
    }

    func remainingMuteDuration(from now: Date = Date()) -> TimeInterval? {
        configuration.remainingMuteDuration(from: now)
    }
}
