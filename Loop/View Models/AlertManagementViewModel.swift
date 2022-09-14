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
    private var alertMuter: AlertMuter

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

    var allowedDurations: [TimeInterval] {
        alertMuter.allowedDurations
    }

    init(alertMuter: AlertMuter) {
        self.alertMuter = alertMuter
        self.enabled = alertMuter.alertMuterConfiguration.enabled
        self.selectedDuration = alertMuter.alertMuterConfiguration.duration
    }
}
