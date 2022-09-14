//
//  AlertManagementViewModel.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2022-09-12.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

class AlertManagementViewModel: ObservableObject {
    private let alertMuter: AlertMuter

    var alertMuterConfiguration: AlertMuterConfiguration {
        get {
            alertMuter.alertMuterConfiguration
        }
        set {
            if alertMuter.alertMuterConfiguration != newValue {
                alertMuter.alertMuterConfiguration = newValue
            }
        }
    }

    @Published var selectedDuration: TimeInterval {
        didSet {
            alertMuter.alertMuterConfiguration.duration = selectedDuration
        }
    }

    @Published var enabled: Bool {
        didSet {
            alertMuter.alertMuterConfiguration.enabled = enabled
        }
    }

    let allowedDurations: [TimeInterval] = [.minutes(30), .hours(1), .hours(2), .hours(4)]

    private var formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()

    init(alertMuter: AlertMuter) {
        self.alertMuter = alertMuter
        self.enabled = alertMuter.alertMuterConfiguration.enabled
        self.selectedDuration = alertMuter.alertMuterConfiguration.duration
    }
}
