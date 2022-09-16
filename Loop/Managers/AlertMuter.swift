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
            guard let enabled = rawValue[ConfigurationKey.enabled.rawValue] as? Bool
            else { return nil }

            self.enabled = enabled
            self.duration = rawValue[ConfigurationKey.enabled.rawValue] as? TimeInterval
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
        var duration: TimeInterval?
        private(set) var startTime: Date?

        init(enabled: Bool, duration: TimeInterval?) {
            self.enabled = enabled
            self.duration = enabled ? duration : nil
            self.startTime = enabled ? Date() : nil
        }

        var shouldMuteAlerts: Bool {
            shouldMuteAlert()
        }

        func shouldMuteAlert(_ fromNow: TimeInterval = 0) -> Bool {
            guard fromNow >= 0 else { return false }

            guard enabled,
                  let startTime = startTime
            else { return false }

            let now = Date().advanced(by: fromNow)
            guard let duration = duration,
                  now < startTime.addingTimeInterval(duration)
            else { return false }

            return true
        }
    }

    @Published var configuration: Configuration

    private lazy var cancellables = Set<AnyCancellable>()

    var allowedDurations: [TimeInterval] { [.minutes(30), .hours(1), .hours(2), .hours(4)] }

    init(configuration: Configuration = Configuration(enabled: false, duration: nil)) {
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

    convenience init(enabled: Bool = false, duration: TimeInterval? = nil) {
        self.init(configuration: Configuration(enabled: enabled, duration: duration))
    }

    func check() {
        // this is enabled by user action, so only need to check if the duration has elapsed and then disable
        guard !configuration.shouldMuteAlerts else { return }
        configuration.enabled = false
    }

    func shouldMuteAlert(_ fromNow: TimeInterval) -> Bool {
        configuration.shouldMuteAlert(fromNow)
    }

    func processAlert(_ alert: LoopKit.Alert) -> LoopKit.Alert {
        switch alert.trigger {
        case .immediate:
            return alert.makeMutedAlert(configuration.shouldMuteAlerts)
        case .delayed(let interval), .repeating(let interval):
            return alert.makeMutedAlert(configuration.shouldMuteAlert(interval))
        }
    }
}
