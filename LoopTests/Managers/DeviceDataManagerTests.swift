//
//  DeviceDataManagerTests.swift
//  LoopTests
//
//  Created by Pete Schwamb on 10/31/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit
@testable import Loop

final class DeviceDataManagerTests: XCTestCase {

    var deviceDataManager: DeviceDataManager!
    let mockDecisionStore = MockDosingDecisionStore()
    let pumpManager: MockPumpManager = MockPumpManager()
    let cgmManager: MockCGMManager = MockCGMManager()
    let trustedTimeChecker = MockTrustedTimeChecker()
    var settingsManager: SettingsManager!

    class MockAlertIssuer: AlertIssuer {
        func issueAlert(_ alert: LoopKit.Alert) {
        }

        func retractAlert(identifier: LoopKit.Alert.Identifier) {
        }
    }

    @MainActor
    override func setUpWithError() throws {
        let mockUserNotificationCenter = MockUserNotificationCenter()
        let mockBluetoothProvider = MockBluetoothProvider()
        let alertPresenter = MockPresenter()
        let automaticDosingStatus = AutomaticDosingStatus(automaticDosingEnabled: true, isAutomaticDosingAllowed: true)

        let alertManager = AlertManager(
            alertPresenter: alertPresenter,
            userNotificationAlertScheduler: MockUserNotificationAlertScheduler(userNotificationCenter: mockUserNotificationCenter),
            bluetoothProvider: mockBluetoothProvider,
            analyticsServicesManager: AnalyticsServicesManager()
        )

        let persistenceController = PersistenceController.mock()

        let healthStore = HKHealthStore()

        let carbAbsorptionTimes: CarbStore.DefaultAbsorptionTimes = (fast: .minutes(30), medium: .hours(3), slow: .hours(5))

        let carbStore = CarbStore(
            cacheStore: persistenceController,
            cacheLength: .days(1),
            defaultAbsorptionTimes: carbAbsorptionTimes
        )

        let doseStore = DoseStore(
            cacheStore: persistenceController,
            insulinModelProvider: PresetInsulinModelProvider(defaultRapidActingModel: nil)
        )

        let glucoseStore = GlucoseStore(cacheStore: persistenceController)

        let cgmEventStore = CgmEventStore(cacheStore: persistenceController)

        let alertStore = AlertStore()

        let dosingDecisionStore = DosingDecisionStore(store: persistenceController, expireAfter: .days(1))

        let settingsStore = SettingsStore(store: persistenceController, expireAfter: .days(1))

        let remoteDataServicesManager = RemoteDataServicesManager(
            alertStore: alertStore,
            carbStore: carbStore,
            doseStore: doseStore,
            dosingDecisionStore: dosingDecisionStore,
            glucoseStore: glucoseStore,
            cgmEventStore: cgmEventStore,
            settingsStore: settingsStore,
            overrideHistory: TemporaryScheduleOverrideHistory(),
            insulinDeliveryStore: doseStore.insulinDeliveryStore
        )

        self.settingsManager = SettingsManager(cacheStore: persistenceController, expireAfter: .days(1), alertMuter: AlertMuter())

        let a = DeviceDataManager(
            pluginManager: <#T##PluginManager#>,
            alertManager: <#T##AlertManager#>,
            settingsManager: <#T##SettingsManager#>,
            healthStore: <#T##HKHealthStore#>,
            carbStore: <#T##CarbStore#>,
            doseStore: <#T##DoseStore#>,
            glucoseStore: <#T##GlucoseStore#>,
            cgmEventStore: <#T##CgmEventStore#>,
            remoteDataServicesManager: <#T##RemoteDataServicesManager#>,
            crashRecoveryManager: <#T##CrashRecoveryManager#>,
            statefulPluginManager: <#T##StatefulPluginManager#>,
            loopControl: <#T##LoopControl#>,
            analyticsServicesManager: <#T##AnalyticsServicesManager#>,
            servicesManager: <#T##ServicesManager#>,
            bluetoothProvider: <#T##BluetoothProvider#>,
            alertPresenter: <#T##AlertPresenter#>,
            automaticDosingStatus: <#T##AutomaticDosingStatus#>,
            cacheStore: <#T##PersistenceController#>,
            localCacheDuration: <#T##TimeInterval#>,
            displayGlucosePreference: <#T##DisplayGlucosePreference#>,
            displayGlucoseUnitBroadcaster: <#T##DisplayGlucoseUnitBroadcaster#>
        )

        let pluginManager = PluginManager()
        let analyticsServicesManager = AnalyticsServicesManager()

        let servicesManager = ServicesManager(
            pluginManager: pluginManager,
            alertManager: alertManager,
            analyticsServicesManager: analyticsServicesManager,
            loggingServicesManager: LoggingServicesManager(),
            remoteDataServicesManager: remoteDataServicesManager,
            settingsManager: settingsManager,
            servicesManagerDelegate: <#T##ServicesManagerDelegate#>,
            servicesManagerDosingDelegate: <#T##ServicesManagerDosingDelegate#>
        )
        let statefulPluginManager = StatefulPluginManager(pluginManager: pluginManager, servicesManager: servi)

        deviceDataManager = DeviceDataManager(
            pluginManager: PluginManager(),
            alertManager: alertManager,
            settingsManager: settingsManager,
            healthStore: healthStore,
            carbStore: carbStore,
            doseStore: doseStore,
            glucoseStore: glucoseStore,
            cgmEventStore: cgmEventStore,
            remoteDataServicesManager: remoteDataServicesManager,
            crashRecoveryManager: CrashRecoveryManager(alertIssuer: MockAlertIssuer()),
            statefulPluginManager: StatefulPluginManager(pluginManager: <#T##PluginManager#>, servicesManager: <#T##ServicesManager#>)
            loopControl: LoopControlMock(),
            analyticsServicesManager: AnalyticsServicesManager(),
            bluetoothProvider: mockBluetoothProvider,
            alertPresenter: alertPresenter,
            automaticDosingStatus: automaticDosingStatus,
            cacheStore: persistenceController,
            localCacheDuration: .days(1)
        )

        deviceDataManager.pumpManager = pumpManager
        deviceDataManager.cgmManager = cgmManager
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testValidateMaxTempBasalDoesntCancelTempBasalIfHigher() async throws {
        let dose = DoseEntry(
            type: .tempBasal,
            startDate: Date(),
            value: 3.0,
            unit: .unitsPerHour,
            automatic: true
        )
        pumpManager.status.basalDeliveryState = .tempBasal(dose)

        let newLimits = DeliveryLimits(
            maximumBasalRate: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 5),
            maximumBolus: nil
        )
        let limits = try await deviceDataManager.syncDeliveryLimits(deliveryLimits: newLimits)

        XCTAssertNil(mockDosingManager.lastCancelActiveTempBasalReason)
        XCTAssertTrue(mockDecisionStore.dosingDecisions.isEmpty)
        XCTAssertEqual(limits.maximumBasalRate, newLimits.maximumBasalRate)
    }

    func testValidateMaxTempBasalCancelsTempBasalIfLower() async throws {
        let dose = DoseEntry(
            type: .tempBasal,
            startDate: Date(),
            endDate: nil,
            value: 5.0,
            unit: .unitsPerHour
        )
        pumpManager.status.basalDeliveryState = .tempBasal(dose)

        let newLimits = DeliveryLimits(
            maximumBasalRate: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 3),
            maximumBolus: nil
        )
        let limits = try await deviceDataManager.syncDeliveryLimits(deliveryLimits: newLimits)

        XCTAssertEqual(.maximumBasalRateChanged, mockDosingManager.lastCancelActiveTempBasalReason)
        XCTAssertEqual(limits.maximumBasalRate, newLimits.maximumBasalRate)

        XCTAssertEqual(mockDecisionStore.dosingDecisions.count, 1)
        XCTAssertEqual(mockDecisionStore.dosingDecisions[0].reason, "maximumBasalRateChanged")
        XCTAssertEqual(mockDecisionStore.dosingDecisions[0].automaticDoseRecommendation, AutomaticDoseRecommendation(basalAdjustment: .cancel))
    }

    func testReceivedUnreliableCGMReadingCancelsTempBasal() {
        let dose = DoseEntry(
            type: .tempBasal,
            startDate: Date(),
            value: 5.0,
            unit: .unitsPerHour
        )
        pumpManager.status.basalDeliveryState = .tempBasal(dose)

        settingsManager.mutateLoopSettings { settings in
            settings.basalRateSchedule = BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: 0, value: 3.0)])
        }

        mockDosingManager.cancelExpectation = expectation(description: "Temp basal cancel")

        cgmManager.delegateQueue.async {
            self.deviceDataManager.cgmManager(self.cgmManager, hasNew: .unreliableData)
        }

        wait(for: [mockDosingManager.cancelExpectation!], timeout: 1)

        XCTAssertEqual(mockDosingManager.lastCancelActiveTempBasalReason, .unreliableCGMData)
    }

    func testLoopGetStateRecommendsManualBolusWithoutMomentum() {
//        setUp(for: .highAndRisingWithCOB)
//        let exp = expectation(description: #function)
//        var recommendedBolus: ManualBolusRecommendation?
//        loopDataManager.getLoopState { (_, loopState) in
//            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: false)
//            exp.fulfill()
//        }
//        wait(for: [exp], timeout: 1.0)
//        XCTAssertEqual(recommendedBolus!.amount, 1.52, accuracy: 0.01)
    }

}
