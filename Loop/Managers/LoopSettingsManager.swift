//
//  LoopSettingsManager.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2020-10-28.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopCore

class LoopSettingsManager {
    //TODO add tests
    private let alertManager: AlertPresenter?

    @Published var settings: LoopSettings

    init(alertManager: AlertPresenter? = nil,
         settings: LoopSettings = UserDefaults.appGroup?.loopSettings ?? LoopSettings())
    {
        self.alertManager = alertManager
        self.settings = settings

        NotificationCenter.default.addObserver(forName: .LoopRunning,
                                               object: nil,
                                               queue: nil
        ) {
            [weak self] _ in self?.checkAlerts()
        }
    }

    private func checkAlerts() {
        checkWorkoutOverrideReminder()
    }

    private func checkWorkoutOverrideReminder() {
        guard settings.isScheduleOverrideInfiniteWorkout else {
            settings.indefiniteWorkoutOverrideEnabledDate = nil
            return
        }

        guard let indefiniteWorkoutOverrideEnabledDate = settings.indefiniteWorkoutOverrideEnabledDate else {
            return
        }

        if  -indefiniteWorkoutOverrideEnabledDate.timeIntervalSinceNow > settings.workoutOverrideReminderInterval {
            issueWorkoutOverrideReminder()
            // reset the date to allow the alert to be issued again after the workoutOverrideReminderInterval is surpassed
            settings.indefiniteWorkoutOverrideEnabledDate = Date()
        }
    }

    private func issueWorkoutOverrideReminder() {
        alertManager?.issueAlert(settings.workoutOverrideReminderAlert)
    }
}
