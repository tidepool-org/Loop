//
//  DeviceDataManager.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/30/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import BackgroundTasks
import HealthKit
import LoopKit
import LoopKitUI
import LoopCore
import LoopTestingKit
import UserNotifications
import Combine

@MainActor
final class DeviceDataManager {

    private let log = DiagnosticLog(category: "DeviceDataManager")

    let pluginManager: PluginManager
    weak var alertManager: AlertManager!
    let bluetoothProvider: BluetoothProvider
    weak var onboardingManager: OnboardingManager?

    /// Remember the launch date of the app for diagnostic reporting
    private let launchDate = Date()

    /// The last error recorded by a device manager
    private(set) var lastError: (date: Date, error: Error)?

    private var deviceLog: PersistentDeviceLog

    // MARK: - App-level responsibilities

    private var alertPresenter: AlertPresenter
    
    private var deliveryUncertaintyAlertManager: DeliveryUncertaintyAlertManager?
    
    @Published var cgmHasValidSensorSession: Bool

    @Published var pumpIsAllowingAutomation: Bool

    private var lastCGMLoopTrigger: Date = .distantPast

    private let automaticDosingStatus: AutomaticDosingStatus

    var closedLoopDisallowedLocalizedDescription: String? {
        if !cgmHasValidSensorSession {
            return NSLocalizedString("Closed Loop requires an active CGM Sensor Session", comment: "The description text for the looping enabled switch cell when closed loop is not allowed because the sensor is inactive")
        } else if !pumpIsAllowingAutomation {
            return NSLocalizedString("Your pump is delivering a manual temporary basal rate.", comment: "The description text for the looping enabled switch cell when closed loop is not allowed because the pump is delivering a manual temp basal.")
        } else {
            return nil
        }
    }

    lazy private var cancellables = Set<AnyCancellable>()
    
    lazy var allowedInsulinTypes: [InsulinType] = {
        var allowed = InsulinType.allCases
        if !FeatureFlags.fiaspInsulinModelEnabled {
            allowed.remove(.fiasp)
        }
        if !FeatureFlags.lyumjevInsulinModelEnabled {
            allowed.remove(.lyumjev)
        }
        if !FeatureFlags.afrezzaInsulinModelEnabled {
            allowed.remove(.afrezza)
        }

        for insulinType in InsulinType.allCases {
            if !insulinType.pumpAdministerable {
                allowed.remove(insulinType)
            }
        }

        return allowed
    }()

    private var cgmStalenessMonitor: CGMStalenessMonitor

    var deviceWhitelist = DeviceWhitelist()

    // MARK: - CGM

    var cgmManager: CGMManager? {
        didSet {
            setupCGM()

            if cgmManager?.pluginIdentifier != oldValue?.pluginIdentifier {
                if let cgmManager = cgmManager {
                    analyticsServicesManager.cgmWasAdded(identifier: cgmManager.pluginIdentifier)
                } else {
                    analyticsServicesManager.cgmWasRemoved()
                }
            }

            NotificationCenter.default.post(name: .CGMManagerChanged, object: self, userInfo: nil)
            rawCGMManager = cgmManager?.rawValue
            UserDefaults.appGroup?.clearLegacyCGMManagerRawValue()
        }
    }

    @PersistedProperty(key: "CGMManagerState")
    var rawCGMManager: CGMManager.RawValue?

    // MARK: - Pump

    var pumpManager: PumpManager? {
        didSet {
            // If the current CGMManager is a PumpManager, we clear it out.
            if cgmManager is PumpManagerUI {
                cgmManager = nil
            }

            if pumpManager?.pluginIdentifier != oldValue?.pluginIdentifier {
                if let pumpManager = pumpManager {
                    analyticsServicesManager.pumpWasAdded(identifier: pumpManager.pluginIdentifier)
                } else {
                    analyticsServicesManager.pumpWasRemoved()
                }
            }

            setupPump()

            NotificationCenter.default.post(name: .PumpManagerChanged, object: self, userInfo: nil)

            rawPumpManager = pumpManager?.rawValue
            UserDefaults.appGroup?.clearLegacyPumpManagerRawValue()
        }
    }

    @PersistedProperty(key: "PumpManagerState")
    var rawPumpManager: PumpManager.RawValue?

    
    var doseEnactor = DoseEnactor()
    
    // MARK: Stores
    let healthStore: HKHealthStore
    
    let carbStore: CarbStore
    
    let doseStore: DoseStore
    
    let glucoseStore: GlucoseStore

    let cgmEventStore: CgmEventStore

    private let cacheStore: PersistenceController

    var dosingDecisionStore: DosingDecisionStoreProtocol

    /// All the HealthKit types to be read by stores
    private var readTypes: Set<HKSampleType> {
        var readTypes: Set<HKSampleType> = []

        if FeatureFlags.observeHealthKitCarbSamplesFromOtherApps {
            readTypes.insert(HealthKitSampleStore.carbType)
        }
        if FeatureFlags.observeHealthKitDoseSamplesFromOtherApps {
            readTypes.insert(HealthKitSampleStore.insulinQuantityType)
        }
        if FeatureFlags.observeHealthKitGlucoseSamplesFromOtherApps {
            readTypes.insert(HealthKitSampleStore.glucoseType)
        }

        readTypes.insert(HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!)

        return readTypes
    }
    
    /// All the HealthKit types to be shared by stores
    private var shareTypes: Set<HKSampleType> {
        return Set([
            HealthKitSampleStore.glucoseType,
            HealthKitSampleStore.carbType,
            HealthKitSampleStore.insulinQuantityType,
        ])
    }

    var sleepDataAuthorizationRequired: Bool {
        return healthStore.authorizationStatus(for: HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!) == .notDetermined
    }
    
    var sleepDataSharingDenied: Bool {
        return healthStore.authorizationStatus(for: HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!) == .sharingDenied
    }

    /// True if any stores require HealthKit authorization
    var authorizationRequired: Bool {
        return healthStore.authorizationStatus(for: HealthKitSampleStore.glucoseType) == .notDetermined ||
               healthStore.authorizationStatus(for: HealthKitSampleStore.carbType) == .notDetermined ||
               healthStore.authorizationStatus(for: HealthKitSampleStore.insulinQuantityType) == .notDetermined ||
               sleepDataAuthorizationRequired
    }

    private(set) var statefulPluginManager: StatefulPluginManager!
    
    // MARK: Services

    private(set) var servicesManager: ServicesManager!

    var analyticsServicesManager: AnalyticsServicesManager

    var settingsManager: SettingsManager

    var temporaryPresetsManager: TemporaryPresetsManager

    var remoteDataServicesManager: RemoteDataServicesManager { return servicesManager.remoteDataServicesManager }

    var criticalEventLogExportManager: CriticalEventLogExportManager!

    var crashRecoveryManager: CrashRecoveryManager

    private(set) var pumpManagerHUDProvider: HUDProvider?

    private var trustedTimeChecker: TrustedTimeChecker

    public private(set) var displayGlucosePreference: DisplayGlucosePreference

    private(set) var loopDataManager: LoopDataManager

    private weak var displayGlucoseUnitBroadcaster: DisplayGlucoseUnitBroadcaster?

    init(pluginManager: PluginManager,
         alertManager: AlertManager,
         settingsManager: SettingsManager,
         loggingServicesManager: LoggingServicesManager,
         healthStore: HKHealthStore,
         carbStore: CarbStore,
         doseStore: DoseStore,
         glucoseStore: GlucoseStore,
         dosingDecisionStore: DosingDecisionStoreProtocol,
         loopDataManager: LoopDataManager,
         analyticsServicesManager: AnalyticsServicesManager,
         bluetoothProvider: BluetoothProvider,
         alertPresenter: AlertPresenter,
         automaticDosingStatus: AutomaticDosingStatus,
         cacheStore: PersistenceController,
         localCacheDuration: TimeInterval,
         overrideHistory: TemporaryScheduleOverrideHistory,
         temporaryPresetsManager: TemporaryPresetsManager,
         trustedTimeChecker: TrustedTimeChecker,
         displayGlucosePreference: DisplayGlucosePreference,
         displayGlucoseUnitBroadcaster: DisplayGlucoseUnitBroadcaster
    ) {

        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let deviceLogDirectory = documentsDirectory.appendingPathComponent("DeviceLog")
        if !fileManager.fileExists(atPath: deviceLogDirectory.path) {
            do {
                try fileManager.createDirectory(at: deviceLogDirectory, withIntermediateDirectories: false)
            } catch let error {
                preconditionFailure("Could not create DeviceLog directory: \(error)")
            }
        }
        deviceLog = PersistentDeviceLog(storageFile: deviceLogDirectory.appendingPathComponent("Storage.sqlite"), maxEntryAge: localCacheDuration)

        self.pluginManager = pluginManager
        self.alertManager = alertManager
        self.settingsManager = settingsManager
        self.healthStore = healthStore
        self.carbStore = carbStore
        self.doseStore = doseStore
        self.glucoseStore = glucoseStore
        self.dosingDecisionStore = dosingDecisionStore
        self.loopDataManager = loopDataManager
        self.analyticsServicesManager = analyticsServicesManager
        self.bluetoothProvider = bluetoothProvider
        self.alertPresenter = alertPresenter
        self.automaticDosingStatus = automaticDosingStatus
        self.cacheStore = cacheStore
        self.temporaryPresetsManager = temporaryPresetsManager
        self.displayGlucosePreference = displayGlucosePreference
        self.displayGlucoseUnitBroadcaster = displayGlucoseUnitBroadcaster

        cgmStalenessMonitor = CGMStalenessMonitor()
        cgmStalenessMonitor.delegate = glucoseStore

        cgmEventStore = CgmEventStore(cacheStore: cacheStore, cacheLength: localCacheDuration)

        cgmHasValidSensorSession = false
        pumpIsAllowingAutomation = true

        self.trustedTimeChecker = trustedTimeChecker

        crashRecoveryManager = CrashRecoveryManager(alertIssuer: alertManager)
        alertManager.addAlertResponder(managerIdentifier: crashRecoveryManager.managerIdentifier, alertResponder: crashRecoveryManager)

        // Turn off preMeal when going into closed loop off mode
        // Cancel any active temp basal when going into closed loop off mode
        // The dispatch is necessary in case this is coming from a didSet already on the settings struct.
        self.automaticDosingStatus.$automaticDosingEnabled
            .removeDuplicates()
            .dropFirst()
            .sink { if !$0 {
                // TODO: update settings
//                self.mutateSettings { settings in
//                    settings.clearOverride(matching: .preMeal)
//                }
                Task {
                    await self.loopDataManager.cancelActiveTempBasal(for: .automaticDosingDisabled)
                }
            } }
            .store(in: &cancellables)

        let remoteDataServicesManager = RemoteDataServicesManager(
            alertStore: alertManager.alertStore,
            carbStore: carbStore,
            doseStore: doseStore,
            dosingDecisionStore: dosingDecisionStore,
            glucoseStore: glucoseStore,
            cgmEventStore: cgmEventStore,
            settingsStore: settingsManager.settingsStore,
            overrideHistory: overrideHistory,
            insulinDeliveryStore: doseStore.insulinDeliveryStore
        )

        settingsManager.remoteDataServicesManager = remoteDataServicesManager
        
        servicesManager = ServicesManager(
            pluginManager: pluginManager,
            alertManager: alertManager,
            analyticsServicesManager: analyticsServicesManager,
            loggingServicesManager: loggingServicesManager,
            remoteDataServicesManager: remoteDataServicesManager,
            settingsManager: settingsManager,
            servicesManagerDelegate: loopDataManager,
            servicesManagerDosingDelegate: self
        )
        
        statefulPluginManager = StatefulPluginManager(pluginManager: pluginManager, servicesManager: servicesManager)
        
        let criticalEventLogs: [CriticalEventLog] = [settingsManager.settingsStore, glucoseStore, carbStore, dosingDecisionStore, doseStore, deviceLog, alertManager.alertStore]
        criticalEventLogExportManager = CriticalEventLogExportManager(logs: criticalEventLogs,
                                                                      directory: FileManager.default.exportsDirectoryURL,
                                                                      historicalDuration: localCacheDuration)

        alertManager.alertStore.delegate = self
        carbStore.delegate = self
        doseStore.delegate = self
        self.dosingDecisionStore.delegate = self
        glucoseStore.delegate = self
        cgmEventStore.delegate = self
        doseStore.insulinDeliveryStore.delegate = self
        remoteDataServicesManager.delegate = self
        
        setupPump()
        setupCGM()

        cgmStalenessMonitor.$cgmDataIsStale
            .combineLatest($cgmHasValidSensorSession)
            .map { $0 == false || $1 }
            .combineLatest($pumpIsAllowingAutomation)
            .map { $0 && $1 }
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .assign(to: \.automaticDosingStatus.isAutomaticDosingAllowed, on: self)
            .store(in: &cancellables)
    }

    func instantiateDeviceManagers() {
        if let pumpManagerRawValue = rawPumpManager ?? UserDefaults.appGroup?.legacyPumpManagerRawValue {
            pumpManager = pumpManagerFromRawValue(pumpManagerRawValue)
            // Update lastPumpEventsReconciliation on DoseStore
            if let lastSync = pumpManager?.lastSync {
                doseStore.addPumpEvents([], lastReconciliation: lastSync) { _ in }
            }
            if let status = pumpManager?.status {
                updatePumpIsAllowingAutomation(status: status)
            }
        } else {
            pumpManager = nil
        }

        if let cgmManagerRawValue = rawCGMManager ?? UserDefaults.appGroup?.legacyCGMManagerRawValue {
            cgmManager = cgmManagerFromRawValue(cgmManagerRawValue)

            // Handle case of PumpManager providing CGM
            if cgmManager == nil && pumpManagerTypeFromRawValue(cgmManagerRawValue) != nil {
                cgmManager = pumpManager as? CGMManager
            }
        }
    }

    var availablePumpManagers: [PumpManagerDescriptor] {
        var pumpManagers = pluginManager.availablePumpManagers + availableStaticPumpManagers
        
        pumpManagers = pumpManagers.filter({ pumpManager in
            guard !deviceWhitelist.pumpDevices.isEmpty else {
                return true
            }
            
            return deviceWhitelist.pumpDevices.contains(pumpManager.identifier)
        })
        
        return pumpManagers
    }

    func setupPumpManager(withIdentifier identifier: String, initialSettings settings: PumpManagerSetupSettings, prefersToSkipUserInteraction: Bool) -> Swift.Result<SetupUIResult<PumpManagerViewController, PumpManager>, Error> {
        switch setupPumpManagerUI(withIdentifier: identifier, initialSettings: settings, prefersToSkipUserInteraction: prefersToSkipUserInteraction) {
        case .failure(let error):
            return .failure(error)
        case .success(let success):
            switch success {
            case .userInteractionRequired(let viewController):
                return .success(.userInteractionRequired(viewController))
            case .createdAndOnboarded(let pumpManagerUI):
                return .success(.createdAndOnboarded(pumpManagerUI))
            }
        }
    }

    struct UnknownPumpManagerIdentifierError: Error {}

    func setupPumpManagerUI(withIdentifier identifier: String, initialSettings settings: PumpManagerSetupSettings, prefersToSkipUserInteraction: Bool = false) -> Swift.Result<SetupUIResult<PumpManagerViewController, PumpManagerUI>, Error> {
        guard let pumpManagerUIType = pumpManagerTypeByIdentifier(identifier) else {
            return .failure(UnknownPumpManagerIdentifierError())
        }

        let result = pumpManagerUIType.setupViewController(initialSettings: settings, bluetoothProvider: bluetoothProvider, colorPalette: .default, allowDebugFeatures: FeatureFlags.allowDebugFeatures, prefersToSkipUserInteraction: prefersToSkipUserInteraction, allowedInsulinTypes: allowedInsulinTypes)
        
        if case .createdAndOnboarded(let pumpManagerUI) = result {
            pumpManagerOnboarding(didCreatePumpManager: pumpManagerUI)
            pumpManagerOnboarding(didOnboardPumpManager: pumpManagerUI)
        }

        return .success(result)
    }
    
    public func saveUpdatedBasalRateSchedule(_ basalRateSchedule: BasalRateSchedule) {
        var therapySettings = self.settingsManager.therapySettings
        therapySettings.basalRateSchedule = basalRateSchedule
        self.saveCompletion(therapySettings: therapySettings)
    }

    public func pumpManagerTypeByIdentifier(_ identifier: String) -> PumpManagerUI.Type? {
        return pluginManager.getPumpManagerTypeByIdentifier(identifier) ?? staticPumpManagersByIdentifier[identifier]
    }

    private func pumpManagerTypeFromRawValue(_ rawValue: [String: Any]) -> PumpManager.Type? {
        guard let managerIdentifier = rawValue["managerIdentifier"] as? String else {
            return nil
        }

        return pumpManagerTypeByIdentifier(managerIdentifier)
    }

    func pumpManagerFromRawValue(_ rawValue: [String: Any]) -> PumpManagerUI? {
        guard let rawState = rawValue["state"] as? PumpManager.RawStateValue,
            let Manager = pumpManagerTypeFromRawValue(rawValue)
            else {
                return nil
        }

        return Manager.init(rawState: rawState) as? PumpManagerUI
    }
    
    private func checkPumpDataAndLoop() async {
        guard !crashRecoveryManager.pendingCrashRecovery else {
            self.log.default("Loop paused pending crash recovery acknowledgement.")
            return
        }

        self.log.default("Asserting current pump data")
        guard let pumpManager = pumpManager else {
            // Run loop, even if pump is missing, to ensure stored dosing decision
            await self.loopDataManager.loop()
            return
        }

        let _ = await pumpManager.ensureCurrentPumpData()
        await self.loopDataManager.loop()
    }


    /// An active high temp basal (greater than the basal schedule) is cancelled when the CGM data is unreliable.
    private func receivedUnreliableCGMReading() async {
        guard case .tempBasal(let tempBasal) = pumpManager?.status.basalDeliveryState else {
            return
        }

        guard let scheduledBasalRate = settingsManager.latestSettings.basalRateSchedule?.value(at: tempBasal.startDate),
              tempBasal.unitsPerHour > scheduledBasalRate else
        {
            return
        }

        // Cancel active high temp basal
        await loopDataManager.cancelActiveTempBasal(for: .unreliableCGMData)
    }

    private func processCGMReadingResult(_ manager: CGMManager, readingResult: CGMReadingResult) async {
        switch readingResult {
        case .newData(let values):
            do {
                let _ = try await loopDataManager.addGlucose(values)
            } catch {
                log.error("Unable to store glucose: %{public}@", String(describing: error))
            }
            if !values.isEmpty {
                self.cgmStalenessMonitor.cgmGlucoseSamplesAvailable(values)
            }
        case .unreliableData:
            await self.receivedUnreliableCGMReading()
        case .noData:
            break
        case .error(let error):
            self.setLastError(error: error)
        }
        updatePumpManagerBLEHeartbeatPreference()
    }

    var availableCGMManagers: [CGMManagerDescriptor] {
        var availableCGMManagers = pluginManager.availableCGMManagers + availableStaticCGMManagers
        if let pumpManagerAsCGMManager = pumpManager as? CGMManager {
            availableCGMManagers.append(CGMManagerDescriptor(identifier: pumpManagerAsCGMManager.pluginIdentifier, localizedTitle: pumpManagerAsCGMManager.localizedTitle))
        }
        
        availableCGMManagers = availableCGMManagers.filter({ cgmManager in
            guard !deviceWhitelist.cgmDevices.isEmpty else {
                return true
            }
            
            return deviceWhitelist.cgmDevices.contains(cgmManager.identifier)
        })

        return availableCGMManagers
    }

    func setupCGMManager(withIdentifier identifier: String, prefersToSkipUserInteraction: Bool = false) -> Swift.Result<SetupUIResult<CGMManagerViewController, CGMManager>, Error> {
        if let cgmManager = setupCGMManagerFromPumpManager(withIdentifier: identifier) {
            return .success(.createdAndOnboarded(cgmManager))
        }

        switch setupCGMManagerUI(withIdentifier: identifier, prefersToSkipUserInteraction: prefersToSkipUserInteraction) {
        case .failure(let error):
            return .failure(error)
        case .success(let success):
            switch success {
            case .userInteractionRequired(let viewController):
                return .success(.userInteractionRequired(viewController))
            case .createdAndOnboarded(let cgmManagerUI):
                return .success(.createdAndOnboarded(cgmManagerUI))
            }
        }
    }

    struct UnknownCGMManagerIdentifierError: Error {}

    fileprivate func setupCGMManagerUI(withIdentifier identifier: String, prefersToSkipUserInteraction: Bool) -> Swift.Result<SetupUIResult<CGMManagerViewController, CGMManagerUI>, Error> {
        guard let cgmManagerUIType = cgmManagerTypeByIdentifier(identifier) else {
            return .failure(UnknownCGMManagerIdentifierError())
        }

        let result = cgmManagerUIType.setupViewController(bluetoothProvider: bluetoothProvider, displayGlucosePreference: displayGlucosePreference, colorPalette: .default, allowDebugFeatures: FeatureFlags.allowDebugFeatures, prefersToSkipUserInteraction: prefersToSkipUserInteraction)
        if case .createdAndOnboarded(let cgmManagerUI) = result {
            cgmManagerOnboarding(didCreateCGMManager: cgmManagerUI)
            cgmManagerOnboarding(didOnboardCGMManager: cgmManagerUI)
        }

        return .success(result)
    }

    public func cgmManagerTypeByIdentifier(_ identifier: String) -> CGMManagerUI.Type? {
        return pluginManager.getCGMManagerTypeByIdentifier(identifier) ?? staticCGMManagersByIdentifier[identifier] as? CGMManagerUI.Type
    }
    
    public func setupCGMManagerFromPumpManager(withIdentifier identifier: String) -> CGMManager? {
        guard identifier == pumpManager?.pluginIdentifier, let cgmManager = pumpManager as? CGMManager else {
            return nil
        }

        // We have a pump that is a CGM!
        self.cgmManager = cgmManager
        return cgmManager
    }
    
    private func cgmManagerTypeFromRawValue(_ rawValue: [String: Any]) -> CGMManager.Type? {
        guard let managerIdentifier = rawValue["managerIdentifier"] as? String else {
            return nil
        }

        return cgmManagerTypeByIdentifier(managerIdentifier)
    }

    func cgmManagerFromRawValue(_ rawValue: [String: Any]) -> CGMManagerUI? {
        guard let rawState = rawValue["state"] as? CGMManager.RawStateValue,
            let Manager = cgmManagerTypeFromRawValue(rawValue)
            else {
                return nil
        }

        return Manager.init(rawState: rawState) as? CGMManagerUI
    }
    
    func checkDeliveryUncertaintyState() {
        if let pumpManager = pumpManager, pumpManager.status.deliveryIsUncertain {
            self.deliveryUncertaintyAlertManager?.showAlert()
        }
    }

    func getHealthStoreAuthorization(_ completion: @escaping (HKAuthorizationRequestStatus) -> Void) {
        healthStore.getRequestStatusForAuthorization(toShare: shareTypes, read: readTypes) { (authorizationRequestStatus, _) in
            completion(authorizationRequestStatus)
        }
    }
    
    // Get HealthKit authorization for all of the stores
    func authorizeHealthStore(_ completion: @escaping (HKAuthorizationRequestStatus) -> Void) {
        // Authorize all types at once for simplicity
        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { (success, error) in
            if success {
                // Call the individual authorization methods to trigger query creation
                self.carbStore.hkSampleStore?.authorizationIsDetermined()
                self.doseStore.hkSampleStore?.authorizationIsDetermined()
                self.glucoseStore.hkSampleStore?.authorizationIsDetermined()
            }

            self.getHealthStoreAuthorization(completion)
        }
    }
}

private extension DeviceDataManager {
    func setupCGM() {
        cgmManager?.cgmManagerDelegate = self
        cgmManager?.delegateQueue = DispatchQueue.main
        reportPluginInitializationComplete()

        glucoseStore.managedDataInterval = cgmManager?.managedDataInterval
        glucoseStore.healthKitStorageDelay = cgmManager.map{ type(of: $0).healthKitStorageDelay } ?? 0

        updatePumpManagerBLEHeartbeatPreference()
        if let cgmManager = cgmManager {
            alertManager?.addAlertResponder(managerIdentifier: cgmManager.pluginIdentifier,
                                            alertResponder: cgmManager)
            alertManager?.addAlertSoundVendor(managerIdentifier: cgmManager.pluginIdentifier,
                                              soundVendor: cgmManager)            
            cgmHasValidSensorSession = cgmManager.cgmManagerStatus.hasValidSensorSession

            analyticsServicesManager.identifyCGMType(cgmManager.pluginIdentifier)
        }

        if let cgmManagerUI = cgmManager as? CGMManagerUI {
            displayGlucoseUnitBroadcaster?.addDisplayGlucoseUnitObserver(cgmManagerUI)
        }
    }

    func setupPump() {
        dispatchPrecondition(condition: .onQueue(.main))

        pumpManager?.pumpManagerDelegate = self
        pumpManager?.delegateQueue = DispatchQueue.main
        reportPluginInitializationComplete()

        doseStore.device = pumpManager?.status.device
        pumpManagerHUDProvider = (pumpManager as? PumpManagerUI)?.hudProvider(bluetoothProvider: bluetoothProvider, colorPalette: .default, allowedInsulinTypes: allowedInsulinTypes)

        // Proliferate PumpModel preferences to DoseStore
        if let pumpRecordsBasalProfileStartEvents = pumpManager?.pumpRecordsBasalProfileStartEvents {
            doseStore.pumpRecordsBasalProfileStartEvents = pumpRecordsBasalProfileStartEvents
        }
        if let pumpManager = pumpManager as? PumpManagerUI {
            alertManager?.addAlertResponder(managerIdentifier: pumpManager.pluginIdentifier,
                                                  alertResponder: pumpManager)
            alertManager?.addAlertSoundVendor(managerIdentifier: pumpManager.pluginIdentifier,
                                                    soundVendor: pumpManager)
            
            deliveryUncertaintyAlertManager = DeliveryUncertaintyAlertManager(pumpManager: pumpManager, alertPresenter: alertPresenter)

            analyticsServicesManager.identifyPumpType(pumpManager.pluginIdentifier)
        }
    }

    func setLastError(error: Error) {
        DispatchQueue.main.async {
            self.lastError = (date: Date(), error: error)
        }
    }
}

// MARK: - Plugins
extension DeviceDataManager {
    func reportPluginInitializationComplete() {
        let allActivePlugins = self.allActivePlugins
        
        for plugin in servicesManager.activeServices {
            plugin.initializationComplete(for: allActivePlugins)
        }
        
        for plugin in statefulPluginManager.activeStatefulPlugins {
            plugin.initializationComplete(for: allActivePlugins)
        }
        
        for plugin in availableSupports {
            plugin.initializationComplete(for: allActivePlugins)
        }
        
        cgmManager?.initializationComplete(for: allActivePlugins)
        pumpManager?.initializationComplete(for: allActivePlugins)
    }
    
    var allActivePlugins: [Pluggable] {
        var allActivePlugins: [Pluggable] = servicesManager.activeServices
        
        for plugin in statefulPluginManager.activeStatefulPlugins {
            if !allActivePlugins.contains(where: { $0.pluginIdentifier == plugin.pluginIdentifier }) {
                allActivePlugins.append(plugin)
            }
        }
        
        for plugin in availableSupports {
            if !allActivePlugins.contains(where: { $0.pluginIdentifier == plugin.pluginIdentifier }) {
                allActivePlugins.append(plugin)
            }
        }
        
        if let cgmManager = cgmManager {
            if !allActivePlugins.contains(where: { $0.pluginIdentifier == cgmManager.pluginIdentifier }) {
                allActivePlugins.append(cgmManager)
            }
        }
        
        if let pumpManager = pumpManager {
            if !allActivePlugins.contains(where: { $0.pluginIdentifier == pumpManager.pluginIdentifier }) {
                allActivePlugins.append(pumpManager)
            }
        }
        
        return allActivePlugins
    }
}

// MARK: - Client API
extension DeviceDataManager {
    func enactBolus(units: Double, activationType: BolusActivationType, completion: @escaping (_ error: Error?) -> Void = { _ in }) {
        guard let pumpManager = pumpManager else {
            completion(LoopError.configurationError(.pumpManager))
            return
        }

        pumpManager.enactBolus(units: units, activationType: activationType) { (error) in
            if let error = error {
                self.log.error("%{public}@", String(describing: error))
                switch error {
                case .uncertainDelivery:
                    // Do not generate notification on uncertain delivery error
                    break
                default:
                    // Do not generate notifications for automatic boluses that fail.
                    if !activationType.isAutomatic {
                        NotificationManager.sendBolusFailureNotification(for: error, units: units, at: Date(), activationType: activationType)
                    }
                }
                completion(error)
            } else {
                completion(nil)
            }
        }
        // Trigger forecast/recommendation update for remote clients
        self.loopDataManager.updateRemoteRecommendation()
    }
    
    func enactBolus(units: Double, activationType: BolusActivationType) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            enactBolus(units: units, activationType: activationType) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            }
        }
    }

    var pumpManagerStatus: PumpManagerStatus? {
        return pumpManager?.status
    }

    var cgmManagerStatus: CGMManagerStatus? {
        return cgmManager?.cgmManagerStatus
    }

    func glucoseDisplay(for glucose: GlucoseSampleValue?) -> GlucoseDisplayable? {
        guard let glucose = glucose else {
            return cgmManager?.glucoseDisplay
        }
        
        guard FeatureFlags.cgmManagerCategorizeManualGlucoseRangeEnabled else {
            // Using Dexcom default glucose thresholds to categorize a glucose range
            let urgentLowGlucoseThreshold = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 55)
            let lowGlucoseThreshold = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)
            let highGlucoseThreshold = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200)
            
            let glucoseRangeCategory: GlucoseRangeCategory
            switch glucose.quantity {
            case ...urgentLowGlucoseThreshold:
                glucoseRangeCategory = .urgentLow
            case urgentLowGlucoseThreshold..<lowGlucoseThreshold:
                glucoseRangeCategory = .low
            case lowGlucoseThreshold..<highGlucoseThreshold:
                glucoseRangeCategory = .normal
            default:
                glucoseRangeCategory = .high
            }
            
            if glucose.wasUserEntered {
                return ManualGlucoseDisplay(glucoseRangeCategory: glucoseRangeCategory)
            } else {
                var glucoseDisplay = GlucoseDisplay(cgmManager?.glucoseDisplay)
                glucoseDisplay?.glucoseRangeCategory = glucoseRangeCategory
                return glucoseDisplay
            }
        }
        
        if glucose.wasUserEntered {
            // the CGM manager needs to determine the glucose range category for a manual glucose based on its managed glucose thresholds
            let glucoseRangeCategory = (cgmManager as? CGMManagerUI)?.glucoseRangeCategory(for: glucose)
            return ManualGlucoseDisplay(glucoseRangeCategory: glucoseRangeCategory)
        } else {
            return cgmManager?.glucoseDisplay
        }
    }

    func didBecomeActive() {
        updatePumpManagerBLEHeartbeatPreference()
    }

    func updatePumpManagerBLEHeartbeatPreference() {
        pumpManager?.setMustProvideBLEHeartbeat(pumpManagerMustProvideBLEHeartbeat)
    }
}

// MARK: - DeviceManagerDelegate
extension DeviceDataManager: DeviceManagerDelegate {

    func deviceManager(_ manager: DeviceManager, logEventForDeviceIdentifier deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)?) {
        deviceLog.log(managerIdentifier: manager.pluginIdentifier, deviceIdentifier: deviceIdentifier, type: type, message: message, completion: completion)
    }
    
    var allowDebugFeatures: Bool {
        FeatureFlags.allowDebugFeatures // NOTE: DEBUG FEATURES - DEBUG AND TEST ONLY
    }
}

// MARK: - AlertIssuer
extension DeviceDataManager: AlertIssuer {
    static let managerIdentifier = "DeviceDataManager"

    func issueAlert(_ alert: Alert) {
        alertManager?.issueAlert(alert)
    }

    func retractAlert(identifier: Alert.Identifier) {
        alertManager?.retractAlert(identifier: identifier)
    }
}

// MARK: - PersistedAlertStore
extension DeviceDataManager: PersistedAlertStore {
    func doesIssuedAlertExist(identifier: Alert.Identifier, completion: @escaping (Swift.Result<Bool, Error>) -> Void) {
        precondition(alertManager != nil)
        alertManager.doesIssuedAlertExist(identifier: identifier, completion: completion)
    }
    func lookupAllUnretracted(managerIdentifier: String, completion: @escaping (Swift.Result<[PersistedAlert], Error>) -> Void) {
        precondition(alertManager != nil)
        alertManager.lookupAllUnretracted(managerIdentifier: managerIdentifier, completion: completion)
    }
    
    func lookupAllUnacknowledgedUnretracted(managerIdentifier: String, completion: @escaping (Swift.Result<[PersistedAlert], Error>) -> Void) {
        precondition(alertManager != nil)
        alertManager.lookupAllUnacknowledgedUnretracted(managerIdentifier: managerIdentifier, completion: completion)
    }

    func recordRetractedAlert(_ alert: Alert, at date: Date) {
        precondition(alertManager != nil)
        alertManager.recordRetractedAlert(alert, at: date)
    }
}

// MARK: - CGMManagerDelegate
extension DeviceDataManager: CGMManagerDelegate {
    func cgmManagerWantsDeletion(_ manager: CGMManager) {
        DispatchQueue.main.async {
            self.log.default("CGM manager with identifier '%{public}@' wants deletion", manager.pluginIdentifier)
            if let cgmManagerUI = self.cgmManager as? CGMManagerUI {
                self.displayGlucoseUnitBroadcaster?.removeDisplayGlucoseUnitObserver(cgmManagerUI)
            }
            self.cgmManager = nil
            self.settingsManager.storeSettings()
        }
    }

    func cgmManager(_ manager: CGMManager, hasNew readingResult: CGMReadingResult) {
        Task { @MainActor in
            log.default("CGMManager:%{public}@ did update with %{public}@", String(describing: type(of: manager)), String(describing: readingResult))
            await processCGMReadingResult(manager, readingResult: readingResult)
            let now = Date()
            if case .newData = readingResult, now.timeIntervalSince(self.lastCGMLoopTrigger) > .minutes(4.2) {
                self.log.default("Triggering loop from new CGM data at %{public}@", String(describing: now))
                self.lastCGMLoopTrigger = now
                await self.checkPumpDataAndLoop()
            }
        }
    }

    func cgmManager(_ manager: LoopKit.CGMManager, hasNew events: [PersistedCgmEvent]) {
        Task {
            do {
                try await cgmEventStore.add(events: events)
            } catch {
                self.log.error("Error storing cgm events: %{public}@", error.localizedDescription)
            }
        }
    }

    func startDateToFilterNewData(for manager: CGMManager) -> Date? {
        dispatchPrecondition(condition: .onQueue(.main))
        return glucoseStore.latestGlucose?.startDate
    }

    func cgmManagerDidUpdateState(_ manager: CGMManager) {
        dispatchPrecondition(condition: .onQueue(.main))
        rawCGMManager = manager.rawValue
    }

    func credentialStoragePrefix(for manager: CGMManager) -> String {
        // return string unique to this instance of the CGMManager
        return UUID().uuidString
    }
    
    func cgmManager(_ manager: CGMManager, didUpdate status: CGMManagerStatus) {
        DispatchQueue.main.async {
            if self.cgmHasValidSensorSession != status.hasValidSensorSession {
                self.cgmHasValidSensorSession = status.hasValidSensorSession
            }
        }
    }
}

// MARK: - CGMManagerOnboardingDelegate

extension DeviceDataManager: CGMManagerOnboardingDelegate {
    func cgmManagerOnboarding(didCreateCGMManager cgmManager: CGMManagerUI) {
        log.default("CGM manager with identifier '%{public}@' created", cgmManager.pluginIdentifier)
        self.cgmManager = cgmManager
    }

    func cgmManagerOnboarding(didOnboardCGMManager cgmManager: CGMManagerUI) {
        precondition(cgmManager.isOnboarded)
        log.default("CGM manager with identifier '%{public}@' onboarded", cgmManager.pluginIdentifier)

        Task { @MainActor in
            await refreshDeviceData()
            settingsManager.storeSettings()
        }
    }
}

// MARK: - PumpManagerDelegate
extension DeviceDataManager: PumpManagerDelegate {
    func pumpManager(_ pumpManager: PumpManager, didAdjustPumpClockBy adjustment: TimeInterval) {
        dispatchPrecondition(condition: .onQueue(.main))
        log.default("PumpManager:%{public}@ did adjust pump clock by %fs", String(describing: type(of: pumpManager)), adjustment)

        analyticsServicesManager.pumpTimeDidDrift(adjustment)
    }

    func pumpManagerDidUpdateState(_ pumpManager: PumpManager) {
        dispatchPrecondition(condition: .onQueue(.main))
        log.default("PumpManager:%{public}@ did update state", String(describing: type(of: pumpManager)))

        rawPumpManager = pumpManager.rawValue
    }
    
    func pumpManager(_ pumpManager: PumpManager, didRequestBasalRateScheduleChange basalRateSchedule: BasalRateSchedule, completion: @escaping (Error?) -> Void) {
        saveUpdatedBasalRateSchedule(basalRateSchedule)
        completion(nil)
    }

    func pumpManagerBLEHeartbeatDidFire(_ pumpManager: PumpManager) {
        Task { @MainActor in
            log.default("PumpManager:%{public}@ did fire heartbeat", String(describing: type(of: pumpManager)))
            await refreshCGM()
        }
    }
    
    private func refreshCGM() async {
        guard let cgmManager = cgmManager else {
            return
        }

        let result = await cgmManager.fetchNewDataIfNeeded()

        if case .newData = result {
            self.analyticsServicesManager.didFetchNewCGMData()
        }

        await self.processCGMReadingResult(cgmManager, readingResult: result)

        if self.loopDataManager.lastLoopCompleted == nil || self.loopDataManager.lastLoopCompleted!.timeIntervalSinceNow < -.minutes(4.2) {
            self.log.default("Triggering Loop from refreshCGM()")
            await self.checkPumpDataAndLoop()
        }
    }
    
    func refreshDeviceData() async {
        await refreshCGM()

        guard let pumpManager = self.pumpManager, pumpManager.isOnboarded else {
            return
        }

        await pumpManager.ensureCurrentPumpData()
    }

    func pumpManagerMustProvideBLEHeartbeat(_ pumpManager: PumpManager) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        return pumpManagerMustProvideBLEHeartbeat
    }

    private var pumpManagerMustProvideBLEHeartbeat: Bool {
        /// Controls the management of the RileyLink timer tick, which is a reliably-changing BLE
        /// characteristic which can cause the app to wake. For most users, the G5 Transmitter and
        /// G4 Receiver are reliable as hearbeats, but users who find their resources extremely constrained
        /// due to greedy apps or older devices may choose to always enable the timer by always setting `true`
        return !(cgmManager?.providesBLEHeartbeat == true)
    }

    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        dispatchPrecondition(condition: .onQueue(.main))
        log.default("PumpManager:%{public}@ did update status: %{public}@", String(describing: type(of: pumpManager)), String(describing: status))

        doseStore.device = status.device
        
        if let newBatteryValue = status.pumpBatteryChargeRemaining,
           let oldBatteryValue = oldStatus.pumpBatteryChargeRemaining,
           newBatteryValue - oldBatteryValue >= LoopConstants.batteryReplacementDetectionThreshold {
            analyticsServicesManager.pumpBatteryWasReplaced()
        }

        updatePumpIsAllowingAutomation(status: status)

        // Update the pump-schedule based settings
        settingsManager.setScheduleTimeZone(status.timeZone)

        if status.deliveryIsUncertain != oldStatus.deliveryIsUncertain {
            DispatchQueue.main.async {
                if status.deliveryIsUncertain {
                    self.deliveryUncertaintyAlertManager?.showAlert()
                } else {
                    self.deliveryUncertaintyAlertManager?.clearAlert()
                }
            }
        }
    }

    func updatePumpIsAllowingAutomation(status: PumpManagerStatus) {
        if case .tempBasal(let dose) = status.basalDeliveryState, !(dose.automatic ?? true), dose.endDate > Date() {
            pumpIsAllowingAutomation = false
        } else {
            pumpIsAllowingAutomation = true
        }
    }

    func pumpManagerPumpWasReplaced(_ pumpManager: PumpManager) {
    }
    
    func pumpManagerWillDeactivate(_ pumpManager: PumpManager) {
        dispatchPrecondition(condition: .onQueue(.main))

        log.default("Pump manager with identifier '%{public}@' will deactivate", pumpManager.pluginIdentifier)

        self.pumpManager = nil
        deliveryUncertaintyAlertManager = nil
        settingsManager.storeSettings()
    }

    func pumpManager(_ pumpManager: PumpManager, didUpdatePumpRecordsBasalProfileStartEvents pumpRecordsBasalProfileStartEvents: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))
        log.default("PumpManager:%{public}@ did update pumpRecordsBasalProfileStartEvents to %{public}@", String(describing: type(of: pumpManager)), String(describing: pumpRecordsBasalProfileStartEvents))

        doseStore.pumpRecordsBasalProfileStartEvents = pumpRecordsBasalProfileStartEvents
    }

    func pumpManager(_ pumpManager: PumpManager, didError error: PumpManagerError) {
        dispatchPrecondition(condition: .onQueue(.main))
        log.error("PumpManager:%{public}@ did error: %{public}@", String(describing: type(of: pumpManager)), String(describing: error))

        setLastError(error: error)
    }

    func pumpManager(
        _ pumpManager: PumpManager,
        hasNewPumpEvents events: [NewPumpEvent],
        lastReconciliation: Date?,
        replacePendingEvents: Bool,
        completion: @escaping (_ error: Error?) -> Void)
    {
        dispatchPrecondition(condition: .onQueue(.main))
        log.default("PumpManager:%{public}@ hasNewPumpEvents (lastReconciliation = %{public}@)", String(describing: type(of: pumpManager)), String(describing: lastReconciliation))

        doseStore.addPumpEvents(events, lastReconciliation: lastReconciliation, replacePendingEvents: replacePendingEvents) { (error) in
            if let error = error {
                self.log.error("Failed to addPumpEvents to DoseStore: %{public}@", String(describing: error))
            }

            completion(error)

            if error == nil {
                NotificationCenter.default.post(name: .PumpEventsAdded, object: self, userInfo: nil)
            }
        }
    }

    func pumpManager(
        _ pumpManager: PumpManager,
        didReadReservoirValue units: Double,
        at date: Date,
        completion: @escaping (_ result: Swift.Result<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool), Error>) -> Void
    ) {
        Task { @MainActor in
            dispatchPrecondition(condition: .onQueue(.main))
            log.default("PumpManager:%{public}@ did read reservoir value", String(describing: type(of: pumpManager)))

            do {
                let (newValue, lastValue, areStoredValuesContinuous) = try await loopDataManager.addReservoirValue(units, at: date)
                completion(.success((newValue: newValue, lastValue: lastValue, areStoredValuesContinuous: areStoredValuesContinuous)))
            } catch {
                self.log.error("Failed to addReservoirValue: %{public}@", String(describing: error))
                completion(.failure(error))
            }
        }
    }

    func startDateToFilterNewPumpEvents(for manager: PumpManager) -> Date {
        dispatchPrecondition(condition: .onQueue(.main))
        return doseStore.pumpEventQueryAfterDate
    }

    var automaticDosingEnabled: Bool {
        automaticDosingStatus.automaticDosingEnabled
    }
}

// MARK: - PumpManagerOnboardingDelegate

extension DeviceDataManager: PumpManagerOnboardingDelegate {
    func pumpManagerOnboarding(didCreatePumpManager pumpManager: PumpManagerUI) {
        log.default("Pump manager with identifier '%{public}@' created", pumpManager.pluginIdentifier)
        self.pumpManager = pumpManager
    }

    func pumpManagerOnboarding(didOnboardPumpManager pumpManager: PumpManagerUI) {
        Task { @MainActor in
            precondition(pumpManager.isOnboarded)
            log.default("Pump manager with identifier '%{public}@' onboarded", pumpManager.pluginIdentifier)

            await refreshDeviceData()
            settingsManager.storeSettings()
        }
    }

    func pumpManagerOnboarding(didPauseOnboarding pumpManager: PumpManagerUI) {
        
    }
}

// MARK: - AlertStoreDelegate
extension DeviceDataManager: AlertStoreDelegate {
    func alertStoreHasUpdatedAlertData(_ alertStore: AlertStore) {
        remoteDataServicesManager.triggerUpload(for: .alert)
    }
}

// MARK: - CarbStoreDelegate
extension DeviceDataManager: CarbStoreDelegate {
    func carbStoreHasUpdatedCarbData(_ carbStore: CarbStore) {
        remoteDataServicesManager.triggerUpload(for: .carb)
    }

    func carbStore(_ carbStore: CarbStore, didError error: CarbStore.CarbStoreError) {}
}

// MARK: - DoseStoreDelegate
extension DeviceDataManager: DoseStoreDelegate {
    func doseStoreHasUpdatedPumpEventData(_ doseStore: DoseStore) {
        remoteDataServicesManager.triggerUpload(for: .pumpEvent)
    }
}

// MARK: - DosingDecisionStoreDelegate
extension DeviceDataManager: DosingDecisionStoreDelegate {
    func dosingDecisionStoreHasUpdatedDosingDecisionData(_ dosingDecisionStore: DosingDecisionStore) {
        remoteDataServicesManager.triggerUpload(for: .dosingDecision)
    }
}

// MARK: - GlucoseStoreDelegate
extension DeviceDataManager: GlucoseStoreDelegate {
    func glucoseStoreHasUpdatedGlucoseData(_ glucoseStore: GlucoseStore) {
        remoteDataServicesManager.triggerUpload(for: .glucose)
    }
}

// MARK: - InsulinDeliveryStoreDelegate
extension DeviceDataManager: InsulinDeliveryStoreDelegate {
    func insulinDeliveryStoreHasUpdatedDoseData(_ insulinDeliveryStore: InsulinDeliveryStore) {
        remoteDataServicesManager.triggerUpload(for: .dose)
    }
}

// MARK: - CgmEventStoreDelegate
extension DeviceDataManager: CgmEventStoreDelegate {
    func cgmEventStoreHasUpdatedData(_ cgmEventStore: LoopKit.CgmEventStore) {
        remoteDataServicesManager.triggerUpload(for: .cgmEvent)
    }
}


// MARK: - TestingPumpManager
extension DeviceDataManager {
    func deleteTestingPumpData(completion: ((Error?) -> Void)? = nil) {
        guard let testingPumpManager = pumpManager as? TestingPumpManager else {
            completion?(nil)
            return
        }

        let devicePredicate = HKQuery.predicateForObjects(from: [testingPumpManager.testingDevice])
        let insulinDeliveryStore = doseStore.insulinDeliveryStore
        
        doseStore.resetPumpData { doseStoreError in
            guard doseStoreError == nil else {
                completion?(doseStoreError!)
                return
            }

            let insulinSharingDenied = self.healthStore.authorizationStatus(for: HealthKitSampleStore.insulinQuantityType) == .sharingDenied
            guard !insulinSharingDenied else {
                // only clear cache since access to health kit is denied
                insulinDeliveryStore.purgeCachedInsulinDeliveryObjects() { error in
                    completion?(error)
                }
                return
            }
            
            insulinDeliveryStore.purgeAllDoseEntries(healthKitPredicate: devicePredicate) { error in
                completion?(error)
            }
        }
    }

    func deleteTestingCGMData(completion: ((Error?) -> Void)? = nil) {
        guard let testingCGMManager = cgmManager as? TestingCGMManager else {
            completion?(nil)
            return
        }
        
        let glucoseSharingDenied = self.healthStore.authorizationStatus(for: HealthKitSampleStore.glucoseType) == .sharingDenied
        guard !glucoseSharingDenied else {
            // only clear cache since access to health kit is denied
            glucoseStore.purgeCachedGlucoseObjects() { error in
                completion?(error)
            }
            return
        }

        let predicate = HKQuery.predicateForObjects(from: [testingCGMManager.testingDevice])
        glucoseStore.purgeAllGlucoseSamples(healthKitPredicate: predicate) { error in
            completion?(error)
        }
    }
}

extension DeviceDataManager: BolusDurationEstimator {
    func estimateBolusDuration(bolusUnits: Double) -> TimeInterval? {
        pumpManager?.estimatedDuration(toBolus: bolusUnits)
    }
}

extension Notification.Name {
    static let PumpManagerChanged = Notification.Name(rawValue:  "com.loopKit.notification.PumpManagerChanged")
    static let CGMManagerChanged = Notification.Name(rawValue:  "com.loopKit.notification.CGMManagerChanged")
    static let PumpEventsAdded = Notification.Name(rawValue:  "com.loopKit.notification.PumpEventsAdded")
}

// MARK: - ServicesManagerDosingDelegate

extension DeviceDataManager: ServicesManagerDosingDelegate {
    
    func deliverBolus(amountInUnits: Double) async throws {
        try await enactBolus(units: amountInUnits, activationType: .manualNoRecommendation)
    }
    
}

// MARK: - Critical Event Log Export

extension DeviceDataManager {
    private static var criticalEventLogHistoricalExportBackgroundTaskIdentifier: String { "com.loopkit.background-task.critical-event-log.historical-export" }

    public static func registerCriticalEventLogHistoricalExportBackgroundTask(_ handler: @escaping (BGProcessingTask) -> Void) -> Bool {
        return BGTaskScheduler.shared.register(forTaskWithIdentifier: criticalEventLogHistoricalExportBackgroundTaskIdentifier, using: nil) { handler($0 as! BGProcessingTask) }
    }

    public func handleCriticalEventLogHistoricalExportBackgroundTask(_ task: BGProcessingTask) {
        dispatchPrecondition(condition: .notOnQueue(.main))

        scheduleCriticalEventLogHistoricalExportBackgroundTask(isRetry: true)

        let exporter = criticalEventLogExportManager.createHistoricalExporter()

        task.expirationHandler = {
            self.log.default("Invoked critical event log historical export background task expiration handler - cancelling exporter")
            exporter.cancel()
        }

        DispatchQueue.global(qos: .background).async {
            exporter.export() { error in
                if let error = error {
                    self.log.error("Critical event log historical export errored: %{public}@", String(describing: error))
                }

                self.scheduleCriticalEventLogHistoricalExportBackgroundTask(isRetry: error != nil && !exporter.isCancelled)
                task.setTaskCompleted(success: error == nil)

                self.log.default("Completed critical event log historical export background task")
            }
        }
    }

    public func scheduleCriticalEventLogHistoricalExportBackgroundTask(isRetry: Bool = false) {
        do {
            let earliestBeginDate = isRetry ? criticalEventLogExportManager.retryExportHistoricalDate() : criticalEventLogExportManager.nextExportHistoricalDate()
            let request = BGProcessingTaskRequest(identifier: Self.criticalEventLogHistoricalExportBackgroundTaskIdentifier)
            request.earliestBeginDate = earliestBeginDate
            request.requiresExternalPower = true

            try BGTaskScheduler.shared.submit(request)

            log.default("Scheduled critical event log historical export background task: %{public}@", ISO8601DateFormatter().string(from: earliestBeginDate))
        } catch let error {
            #if IOS_SIMULATOR
            log.debug("Failed to schedule critical event log export background task due to running on simulator")
            #else
            log.error("Failed to schedule critical event log export background task: %{public}@", String(describing: error))
            #endif
        }
    }

    public func removeExportsDirectory() -> Error? {
        let fileManager = FileManager.default
        let exportsDirectoryURL = fileManager.exportsDirectoryURL

        guard fileManager.fileExists(atPath: exportsDirectoryURL.path) else {
            return nil
        }

        do {
            try fileManager.removeItem(at: exportsDirectoryURL)
        } catch let error {
            return error
        }

        return nil
    }
}

// MARK: - Simulated Core Data

extension DeviceDataManager {
    func generateSimulatedHistoricalCoreData(completion: @escaping (Error?) -> Void) {
        guard FeatureFlags.simulatedCoreDataEnabled else {
            fatalError("\(#function) should be invoked only when simulated core data is enabled")
        }

        settingsManager.settingsStore.generateSimulatedHistoricalSettingsObjects() { error in
            guard error == nil else {
                completion(error)
                return
            }
            self.loopDataManager.generateSimulatedHistoricalCoreData() { error in
                guard error == nil else {
                    completion(error)
                    return
                }
                self.deviceLog.generateSimulatedHistoricalDeviceLogEntries() { error in
                    guard error == nil else {
                        completion(error)
                        return
                    }
                    self.alertManager.alertStore.generateSimulatedHistoricalStoredAlerts(completion: completion)
                }
            }
        }
    }

    func purgeHistoricalCoreData(completion: @escaping (Error?) -> Void) {
        guard FeatureFlags.simulatedCoreDataEnabled else {
            fatalError("\(#function) should be invoked only when simulated core data is enabled")
        }

        alertManager.alertStore.purgeHistoricalStoredAlerts() { error in
            guard error == nil else {
                completion(error)
                return
            }
            self.deviceLog.purgeHistoricalDeviceLogEntries() { error in
                guard error == nil else {
                    completion(error)
                    return
                }
                self.loopDataManager.purgeHistoricalCoreData { error in
                    guard error == nil else {
                        completion(error)
                        return
                    }
                    self.settingsManager.purgeHistoricalSettingsObjects(completion: completion)
                }
            }
        }
    }
}

fileprivate extension FileManager {
    var exportsDirectoryURL: URL {
        let applicationSupportDirectory = try! url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return applicationSupportDirectory.appendingPathComponent(Bundle.main.bundleIdentifier!).appendingPathComponent("Exports")
    }
}

//MARK: - CGMStalenessMonitorDelegate protocol conformance

extension GlucoseStore : CGMStalenessMonitorDelegate { }


//MARK: TherapySettingsViewModelDelegate
struct CancelTempBasalFailedError: LocalizedError {
    let reason: Error?
    
    var errorDescription: String? {
        return String(format: NSLocalizedString("%@%@ was unable to cancel your current temporary basal rate, which is higher than the new Max Basal limit you have set. This may result in higher insulin delivery than desired.\n\nConsider suspending insulin delivery manually and then immediately resuming to enact basal delivery with the new limit in place.",
                                                comment: "Alert text for failing to cancel temp basal (1: reason description, 2: app name)"),
                      reasonString, Bundle.main.bundleDisplayName)
    }
    
    private var reasonString: String {
        let paragraphEnd = ".\n\n"
        if let localizedError = reason as? LocalizedError {
            let errors = [localizedError.errorDescription, localizedError.failureReason, localizedError.recoverySuggestion].compactMap { $0 }
            if !errors.isEmpty {
                return errors.joined(separator: ". ") + paragraphEnd
            }
        }
        return reason.map { $0.localizedDescription + paragraphEnd } ?? ""
    }
}

//MARK: - RemoteDataServicesManagerDelegate protocol conformance

extension DeviceDataManager : RemoteDataServicesManagerDelegate {
    var shouldSyncToRemoteService: Bool {
        guard let cgmManager = cgmManager else {
            return true
        }
        return cgmManager.shouldSyncToRemoteService
    }
}

extension DeviceDataManager: TherapySettingsViewModelDelegate {
    
    func syncBasalRateSchedule(items: [RepeatingScheduleValue<Double>], completion: @escaping (Swift.Result<BasalRateSchedule, Error>) -> Void) {
        pumpManager?.syncBasalRateSchedule(items: items, completion: completion)
    }
    
    func syncDeliveryLimits(deliveryLimits: DeliveryLimits) async throws -> DeliveryLimits
    {
        do {
            // FIRST we need to check to make sure if we have to cancel temp basal first
            if let maxRate = deliveryLimits.maximumBasalRate?.doubleValue(for: .internationalUnitsPerHour),
               case .tempBasal(let dose) = basalDeliveryState,
               dose.unitsPerHour > maxRate
            {
                // Temp basal is higher than proposed rate, so should cancel
                await self.loopDataManager.cancelActiveTempBasal(for: .maximumBasalRateChanged)
            }
            return try await pumpManager?.syncDeliveryLimits(limits: deliveryLimits) ?? deliveryLimits
        } catch {
            throw CancelTempBasalFailedError(reason: error)
        }
    }

    func saveCompletion(therapySettings: TherapySettings) {
        settingsManager.mutateLoopSettings { settings in
            settings.glucoseTargetRangeSchedule = therapySettings.glucoseTargetRangeSchedule
            settings.preMealTargetRange = therapySettings.correctionRangeOverrides?.preMeal
            settings.legacyWorkoutTargetRange = therapySettings.correctionRangeOverrides?.workout
            settings.suspendThreshold = therapySettings.suspendThreshold
            settings.basalRateSchedule = therapySettings.basalRateSchedule
            settings.maximumBasalRatePerHour = therapySettings.maximumBasalRatePerHour
            settings.maximumBolus = therapySettings.maximumBolus
            settings.defaultRapidActingModel = therapySettings.defaultRapidActingModel
            settings.carbRatioSchedule = therapySettings.carbRatioSchedule
            settings.insulinSensitivitySchedule = therapySettings.insulinSensitivitySchedule
        }
    }
    
    func pumpSupportedIncrements() -> PumpSupportedIncrements? {
        return pumpManager.map {
            PumpSupportedIncrements(basalRates: $0.supportedBasalRates,
                                    bolusVolumes: $0.supportedBolusVolumes,
                                    maximumBolusVolumes: $0.supportedMaximumBolusVolumes,
                                    maximumBasalScheduleEntryCount: $0.maximumBasalScheduleEntryCount)
        }
    }
}

extension DeviceDataManager: DeviceSupportDelegate {
    var availableSupports: [SupportUI] { [cgmManager, pumpManager].compactMap { $0 as? SupportUI } }

    func generateDiagnosticReport(_ completion: @escaping (_ report: String) -> Void) {
        self.loopDataManager.generateDiagnosticReport { (loopReport) in

            let logDurationHours = 84.0

            self.alertManager.getStoredEntries(startDate: Date() - .hours(logDurationHours)) { (alertReport) in
                self.deviceLog.getLogEntries(startDate: Date() - .hours(logDurationHours)) { (result) in
                    let deviceLogReport: String
                    switch result {
                    case .failure(let error):
                        deviceLogReport = "Error fetching entries: \(error)"
                    case .success(let entries):
                        deviceLogReport = entries.map { "* \($0.timestamp) \($0.managerIdentifier) \($0.deviceIdentifier ?? "") \($0.type) \($0.message)" }.joined(separator: "\n")
                    }

                    let report = [
                        "## Build Details",
                        "* appNameAndVersion: \(Bundle.main.localizedNameAndVersion)",
                        "* profileExpiration: \(BuildDetails.default.profileExpirationString)",
                        "* gitRevision: \(BuildDetails.default.gitRevision ?? "N/A")",
                        "* gitBranch: \(BuildDetails.default.gitBranch ?? "N/A")",
                        "* workspaceGitRevision: \(BuildDetails.default.workspaceGitRevision ?? "N/A")",
                        "* workspaceGitBranch: \(BuildDetails.default.workspaceGitBranch ?? "N/A")",
                        "* sourceRoot: \(BuildDetails.default.sourceRoot ?? "N/A")",
                        "* buildDateString: \(BuildDetails.default.buildDateString ?? "N/A")",
                        "* xcodeVersion: \(BuildDetails.default.xcodeVersion ?? "N/A")",
                        "",
                        "## FeatureFlags",
                        "\(FeatureFlags)",
                        "",
                        alertReport,
                        "",
                        "## DeviceDataManager",
                        "* launchDate: \(self.launchDate)",
                        "* lastError: \(String(describing: self.lastError))",
                        "",
                        "cacheStore: \(String(reflecting: self.cacheStore))",
                        "",
                        self.cgmManager != nil ? String(reflecting: self.cgmManager!) : "cgmManager: nil",
                        "",
                        self.pumpManager != nil ? String(reflecting: self.pumpManager!) : "pumpManager: nil",
                        "",
                        "## Device Communication Log",
                        deviceLogReport,
                        "",
                        String(reflecting: self.watchManager!),
                        "",
                        String(reflecting: self.statusExtensionManager!),
                        "",
                        loopReport,
                        ].joined(separator: "\n")

                    completion(report)
                }
            }
        }
    }
}

extension DeviceDataManager: DeliveryDelegate {
    var isPumpConfigured: Bool {
        return pumpManager != nil
    }

    func roundBasalRate(unitsPerHour: Double) -> Double {
        guard let pumpManager = pumpManager else {
            return unitsPerHour
        }

        return pumpManager.roundToSupportedBasalRate(unitsPerHour: unitsPerHour)
    }

    func roundBolusVolume(units: Double) -> Double {
        guard let pumpManager = pumpManager else {
            return units
        }

        let rounded = pumpManager.roundToSupportedBolusVolume(units: units)
        self.log.default("Rounded %{public}@ to %{public}@", String(describing: units), String(describing: rounded))

        return rounded
    }

    var pumpInsulinType: LoopKit.InsulinType? {
        return pumpManager?.status.insulinType
    }
    
    var isSuspended: Bool {
        return pumpManager?.status.basalDeliveryState?.isSuspended ?? false
    }
    
    func enact(_ recommendation: LoopKit.AutomaticDoseRecommendation) async throws {
        guard let pumpManager = pumpManager else {
            throw LoopError.configurationError(.pumpManager)
        }

        guard !pumpManager.status.deliveryIsUncertain else {
            throw LoopError.connectionError
        }

        log.default("Enacting recommended dose: %{public}@", String(describing: recommendation))

        crashRecoveryManager.dosingStarted(dose: recommendation)
        defer { self.crashRecoveryManager.dosingFinished() }

        try await doseEnactor.enact(recommendation: recommendation, with: pumpManager)
    }

    var basalDeliveryState: PumpManagerStatus.BasalDeliveryState? {
        return pumpManager?.status.basalDeliveryState
    }
}

extension DeviceDataManager: DeviceStatusProvider {}
