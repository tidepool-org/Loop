//
//  SettingsManager.swift
//  Loop
//
//  Created by Pete Schwamb on 2/27/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import UserNotifications
import UIKit
import HealthKit
import Combine
import LoopCore
import LoopKitUI
import os.log


protocol DeviceStatusProvider {
    var pumpManagerStatus: PumpManagerStatus? { get }
    var cgmManagerStatus: CGMManagerStatus? { get }
}

class SettingsManager {

    let settingsStore: SettingsStore

    var remoteDataServicesManager: RemoteDataServicesManager?

    var analyticsServicesManager: AnalyticsServicesManager

    var deviceStatusProvider: DeviceStatusProvider?

    var alertMuter: AlertMuter

    var displayGlucosePreference: DisplayGlucosePreference?

    public var latestSettings: StoredSettings

    private var remoteNotificationRegistrationResult: Swift.Result<Data,Error>?

    private var cancellables: Set<AnyCancellable> = []

    private let log = OSLog(category: "SettingsManager")

    private var loopSettingsLock = UnfairLock()

    @Published private(set) var dosingEnabled: Bool

    init(cacheStore: PersistenceController, expireAfter: TimeInterval, alertMuter: AlertMuter, analyticsServicesManager: AnalyticsServicesManager)
    {
        self.analyticsServicesManager = analyticsServicesManager

        settingsStore = SettingsStore(store: cacheStore, expireAfter: expireAfter)
        self.alertMuter = alertMuter

        if let storedSettings = settingsStore.latestSettings {
            latestSettings = storedSettings
        } else {
            log.default("SettingsStore has no latestSettings: initializing empty StoredSettings.")
            latestSettings = StoredSettings()
        }

        dosingEnabled = latestSettings.dosingEnabled

        settingsStore.delegate = self

        // Migrate old settings from UserDefaults
        if var legacyLoopSettings = UserDefaults.appGroup?.legacyLoopSettings {
            log.default("Migrating settings from UserDefaults")
            legacyLoopSettings.insulinSensitivitySchedule = UserDefaults.appGroup?.legacyInsulinSensitivitySchedule
            legacyLoopSettings.basalRateSchedule = UserDefaults.appGroup?.legacyBasalRateSchedule
            legacyLoopSettings.carbRatioSchedule = UserDefaults.appGroup?.legacyCarbRatioSchedule
            legacyLoopSettings.defaultRapidActingModel = .rapidActingAdult

            storeSettings(newLoopSettings: legacyLoopSettings)

            UserDefaults.appGroup?.removeLegacyLoopSettings()
        }

        self.alertMuter.$configuration
            .sink { [weak self] alertMuterConfiguration in
                guard var notificationSettings = self?.latestSettings.notificationSettings else { return }
                let newTemporaryMuteAlertsSetting = NotificationSettings.TemporaryMuteAlertSetting(enabled: alertMuterConfiguration.shouldMute, duration: alertMuterConfiguration.duration)
                if notificationSettings.temporaryMuteAlertsSetting != newTemporaryMuteAlertsSetting {
                    notificationSettings.temporaryMuteAlertsSetting = newTemporaryMuteAlertsSetting
                    self?.storeSettings(notificationSettings: notificationSettings)
                }
            }
            .store(in: &cancellables)
    }

    var loopSettings: LoopSettings {
        get {
            return LoopSettings(
                dosingEnabled: latestSettings.dosingEnabled,
                glucoseTargetRangeSchedule: latestSettings.glucoseTargetRangeSchedule,
                insulinSensitivitySchedule: latestSettings.insulinSensitivitySchedule,
                basalRateSchedule: latestSettings.basalRateSchedule,
                carbRatioSchedule: latestSettings.carbRatioSchedule,
                preMealTargetRange: latestSettings.preMealTargetRange,
                legacyWorkoutTargetRange: latestSettings.workoutTargetRange,
                overridePresets: latestSettings.overridePresets,
                maximumBasalRatePerHour: latestSettings.maximumBasalRatePerHour,
                maximumBolus: latestSettings.maximumBolus,
                suspendThreshold: latestSettings.suspendThreshold,
                automaticDosingStrategy: latestSettings.automaticDosingStrategy,
                defaultRapidActingModel: latestSettings.defaultRapidActingModel?.presetForRapidActingInsulin)
        }
    }

    private func mergeSettings(newLoopSettings: LoopSettings? = nil, notificationSettings: NotificationSettings? = nil, deviceToken: String? = nil) -> StoredSettings
    {
        let newLoopSettings = newLoopSettings ?? loopSettings
        let newNotificationSettings = notificationSettings ?? settingsStore.latestSettings?.notificationSettings

        return StoredSettings(date: Date(),
                              dosingEnabled: newLoopSettings.dosingEnabled,
                              glucoseTargetRangeSchedule: newLoopSettings.glucoseTargetRangeSchedule,
                              preMealTargetRange: newLoopSettings.preMealTargetRange,
                              workoutTargetRange: newLoopSettings.legacyWorkoutTargetRange,
                              overridePresets: newLoopSettings.overridePresets,
                              maximumBasalRatePerHour: newLoopSettings.maximumBasalRatePerHour,
                              maximumBolus: newLoopSettings.maximumBolus,
                              suspendThreshold: newLoopSettings.suspendThreshold,
                              deviceToken: deviceToken,
                              insulinType: deviceStatusProvider?.pumpManagerStatus?.insulinType,
                              defaultRapidActingModel: newLoopSettings.defaultRapidActingModel.map(StoredInsulinModel.init),
                              basalRateSchedule: newLoopSettings.basalRateSchedule,
                              insulinSensitivitySchedule: newLoopSettings.insulinSensitivitySchedule,
                              carbRatioSchedule: newLoopSettings.carbRatioSchedule,
                              notificationSettings: newNotificationSettings,
                              controllerDevice: UIDevice.current.controllerDevice,
                              cgmDevice: deviceStatusProvider?.cgmManagerStatus?.device,
                              pumpDevice: deviceStatusProvider?.pumpManagerStatus?.device,
                              bloodGlucoseUnit: displayGlucosePreference?.unit,
                              automaticDosingStrategy: newLoopSettings.automaticDosingStrategy)
    }

    func storeSettings(newLoopSettings: LoopSettings? = nil, notificationSettings: NotificationSettings? = nil) {

        var deviceTokenStr: String?

        if case .success(let deviceToken) = remoteNotificationRegistrationResult {
            deviceTokenStr = deviceToken.hexadecimalString
        }

        let mergedSettings = mergeSettings(newLoopSettings: newLoopSettings, notificationSettings: notificationSettings, deviceToken: deviceTokenStr)

        guard latestSettings != mergedSettings else {
            // Skipping unchanged settings store
            return
        }

        latestSettings = mergedSettings

        if remoteNotificationRegistrationResult == nil && FeatureFlags.remoteCommandsEnabled {
            // remote notification registration not finished
            return
        }

        if latestSettings.insulinSensitivitySchedule == nil {
            log.default("Saving settings with no ISF schedule.")
        }

        settingsStore.storeSettings(latestSettings) { error in
            if let error = error {
                self.log.error("Error storing settings: %{public}@", error.localizedDescription)
            }
        }
    }

    /// Sets a new time zone for a the schedule-based settings
    ///
    /// - Parameter timeZone: The time zone
    func setScheduleTimeZone(_ timeZone: TimeZone) {
        self.mutateLoopSettings { settings in
            settings.basalRateSchedule?.timeZone = timeZone
            settings.carbRatioSchedule?.timeZone = timeZone
            settings.insulinSensitivitySchedule?.timeZone = timeZone
            settings.glucoseTargetRangeSchedule?.timeZone = timeZone
        }
    }


    func mutateLoopSettings(_ changes: (_ settings: inout LoopSettings) -> Void) {
        loopSettingsLock.withLock {
            let oldValue = loopSettings
            var newValue = oldValue
            changes(&newValue)

            guard oldValue != newValue else {
                return
            }

            storeSettings(newLoopSettings: newValue)

            if newValue.insulinSensitivitySchedule != oldValue.insulinSensitivitySchedule {
                analyticsServicesManager.didChangeInsulinSensitivitySchedule()
            }

            if newValue.basalRateSchedule != oldValue.basalRateSchedule {
                if let newValue = newValue.basalRateSchedule, let oldValue = oldValue.basalRateSchedule, newValue.items != oldValue.items {
                    analyticsServicesManager.didChangeBasalRateSchedule()
                }
            }

            if newValue.carbRatioSchedule != oldValue.carbRatioSchedule {
                analyticsServicesManager.didChangeCarbRatioSchedule()
            }

            if newValue.defaultRapidActingModel != oldValue.defaultRapidActingModel {
                analyticsServicesManager.didChangeInsulinModel()
            }

            if newValue.dosingEnabled != oldValue.dosingEnabled {
                self.dosingEnabled = newValue.dosingEnabled
            }
        }
    }

    func storeSettingsCheckingNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings() { notificationSettings in
            DispatchQueue.main.async {
                guard let latestSettings = self.settingsStore.latestSettings else {
                    return
                }

                let temporaryMuteAlertSetting = NotificationSettings.TemporaryMuteAlertSetting(enabled: self.alertMuter.configuration.shouldMute, duration: self.alertMuter.configuration.duration)
                let notificationSettings = NotificationSettings(notificationSettings, temporaryMuteAlertsSetting: temporaryMuteAlertSetting)

                if notificationSettings != latestSettings.notificationSettings
                {
                    self.storeSettings(notificationSettings: notificationSettings)
                }
            }
        }
    }

    func didBecomeActive () {
        storeSettingsCheckingNotificationPermissions()
    }

    func remoteNotificationRegistrationDidFinish(_ result: Swift.Result<Data,Error>) {
        self.remoteNotificationRegistrationResult = result
        storeSettings()
    }

    func purgeHistoricalSettingsObjects(completion: @escaping (Error?) -> Void) {
        settingsStore.purgeHistoricalSettingsObjects(completion: completion)
    }
}

extension SettingsManager {
    public var therapySettings: TherapySettings {
        get {
            let settings = self.latestSettings
            return TherapySettings(glucoseTargetRangeSchedule: settings.glucoseTargetRangeSchedule,
                            correctionRangeOverrides: CorrectionRangeOverrides(preMeal: settings.preMealTargetRange, workout: settings.workoutTargetRange),
                            overridePresets: settings.overridePresets,
                            maximumBasalRatePerHour: settings.maximumBasalRatePerHour,
                            maximumBolus: settings.maximumBolus,
                            suspendThreshold: settings.suspendThreshold,
                            insulinSensitivitySchedule: settings.insulinSensitivitySchedule,
                            carbRatioSchedule: settings.carbRatioSchedule,
                            basalRateSchedule: settings.basalRateSchedule,
                            defaultRapidActingModel: settings.defaultRapidActingModel?.presetForRapidActingInsulin)
        }

        set {
            mutateLoopSettings { settings in
                settings.defaultRapidActingModel = newValue.defaultRapidActingModel
                settings.insulinSensitivitySchedule = newValue.insulinSensitivitySchedule
                settings.carbRatioSchedule = newValue.carbRatioSchedule
                settings.basalRateSchedule = newValue.basalRateSchedule
                settings.glucoseTargetRangeSchedule = newValue.glucoseTargetRangeSchedule
                settings.preMealTargetRange = newValue.correctionRangeOverrides?.preMeal
                settings.legacyWorkoutTargetRange = newValue.correctionRangeOverrides?.workout
                settings.suspendThreshold = newValue.suspendThreshold
                settings.maximumBolus = newValue.maximumBolus
                settings.maximumBasalRatePerHour = newValue.maximumBasalRatePerHour
                settings.overridePresets = newValue.overridePresets ?? []
            }
        }
    }
}


// MARK: - SettingsStoreDelegate
extension SettingsManager: SettingsStoreDelegate {
    func settingsStoreHasUpdatedSettingsData(_ settingsStore: SettingsStore) {
        remoteDataServicesManager?.triggerUpload(for: .settings)
    }
}

private extension NotificationSettings {

    init(_ notificationSettings: UNNotificationSettings, temporaryMuteAlertsSetting: TemporaryMuteAlertSetting) {
        let timeSensitiveSetting: NotificationSettings.NotificationSetting
        let scheduledDeliverySetting: NotificationSettings.NotificationSetting

        if #available(iOS 15.0, *) {
            timeSensitiveSetting = NotificationSettings.NotificationSetting(notificationSettings.timeSensitiveSetting)
            scheduledDeliverySetting = NotificationSettings.NotificationSetting(notificationSettings.scheduledDeliverySetting)
        } else {
            timeSensitiveSetting = .unknown
            scheduledDeliverySetting = .unknown
        }

        self.init(authorizationStatus: NotificationSettings.AuthorizationStatus(notificationSettings.authorizationStatus),
                  soundSetting: NotificationSettings.NotificationSetting(notificationSettings.soundSetting),
                  badgeSetting: NotificationSettings.NotificationSetting(notificationSettings.badgeSetting),
                  alertSetting: NotificationSettings.NotificationSetting(notificationSettings.alertSetting),
                  notificationCenterSetting: NotificationSettings.NotificationSetting(notificationSettings.notificationCenterSetting),
                  lockScreenSetting: NotificationSettings.NotificationSetting(notificationSettings.lockScreenSetting),
                  carPlaySetting: NotificationSettings.NotificationSetting(notificationSettings.carPlaySetting),
                  alertStyle: NotificationSettings.AlertStyle(notificationSettings.alertStyle),
                  showPreviewsSetting: NotificationSettings.ShowPreviewsSetting(notificationSettings.showPreviewsSetting),
                  criticalAlertSetting: NotificationSettings.NotificationSetting(notificationSettings.criticalAlertSetting),
                  providesAppNotificationSettings: notificationSettings.providesAppNotificationSettings,
                  announcementSetting: NotificationSettings.NotificationSetting(notificationSettings.announcementSetting),
                  timeSensitiveSetting: timeSensitiveSetting,
                  scheduledDeliverySetting: scheduledDeliverySetting,
                  temporaryMuteAlertsSetting: temporaryMuteAlertsSetting
        )
    }
}


