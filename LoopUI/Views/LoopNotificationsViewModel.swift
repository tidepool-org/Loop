//
//  LoopNotificationsViewModel.swift
//  LoopUI
//
//  Created by Rick Pasetto on 6/5/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import Foundation
import LoopKit
import SwiftUI

public class LoopNotificationsViewModel: ObservableObject {
    
    @Published var notificationsPermissionsGiven = true
    @Published var criticalAlertsPermissionsGiven = true

    lazy public var showWarningPublisher: AnyPublisher<Bool, Never> = {
        $notificationsPermissionsGiven
            .combineLatest($criticalAlertsPermissionsGiven)
            .map { $0 == false || $1 == false }
            .eraseToAnyPublisher()
    }()

    @Published var showWarning = false
    lazy private var trash = Set<AnyCancellable>()

    public init() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) {
            [weak self] _ in
            self?.updateState()
        }
        updateState()
        
        showWarningPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.showWarning, on: self)
            .store(in: &trash)
    }
    
    private func updateState() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsPermissionsGiven = settings.alertSetting == .enabled
                self.criticalAlertsPermissionsGiven = settings.criticalAlertSetting == .enabled
            }
        }
    }
    
    public func gotoSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}
