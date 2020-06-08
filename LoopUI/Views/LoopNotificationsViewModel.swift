//
//  LoopNotificationsViewModel.swift
//  LoopUI
//
//  Created by Rick Pasetto on 6/5/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftUI

public class LoopNotificationsViewModel: ObservableObject {
    private var criticalAlertForcer: ((Bool) -> Void)?
    
    @Published var forceCriticalAlerts: Bool {
        didSet {
            criticalAlertForcer?(forceCriticalAlerts)
        }
    }

    public init(initialValue: Bool, criticalAlertForcer: @escaping (Bool) -> Void) {
        forceCriticalAlerts = initialValue
        self.criticalAlertForcer = criticalAlertForcer
    }
    
}
