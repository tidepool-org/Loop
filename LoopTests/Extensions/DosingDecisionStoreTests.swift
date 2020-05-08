//
//  DosingDecisionStoreTests.swift
//  LoopTests
//
//  Created by Darin Krauss on 5/12/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit

@testable import Loop

class StoredDosingDecisionCodableTests: XCTestCase {
    func testCodable() throws {
        let insulinOnBoard = InsulinValue(startDate: Date(), value: 1.5)
        let carbsOnBoard = CarbValue(startDate: Date(),
                                     endDate: Date().addingTimeInterval(.minutes(30)),
                                     quantity: HKQuantity(unit: .gram(), doubleValue: 45.6))
        let scheduleOverride = TemporaryScheduleOverride(context: .custom,
                                                         settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                     targetRange: DoubleRange(minValue: 80.0,
                                                                                                                              maxValue: 90.0),
                                                                                                     insulinNeedsScaleFactor: 0.75),
                                                         startDate: Date(),
                                                         duration: .finite(.minutes(45)),
                                                         enactTrigger: .local,
                                                         syncIdentifier: UUID())
        let glucoseTargetRangeSchedule = GlucoseRangeSchedule(rangeSchedule: DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                                                                   dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
                                                                                                                RepeatingScheduleValue(startTime: .hours(7), value: DoubleRange(minValue: 90.0, maxValue: 100.0)),
                                                                                                                RepeatingScheduleValue(startTime: .hours(21), value: DoubleRange(minValue: 110.0, maxValue: 120.0))],
                                                                                                   timeZone: TimeZone.current)!,
                                                              override: GlucoseRangeSchedule.Override(value: DoubleRange(minValue: 105.0, maxValue: 115.0),
                                                                                                      start: Date(),
                                                                                                      end: Date().addingTimeInterval(.minutes(30))))
        let glucoseTargetRangeScheduleApplyingOverrideIfActive = GlucoseRangeSchedule(rangeSchedule: DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                                                                                           dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
                                                                                                                                        RepeatingScheduleValue(startTime: .hours(7), value: DoubleRange(minValue: 90.0, maxValue: 100.0)),
                                                                                                                                        RepeatingScheduleValue(startTime: .hours(21), value: DoubleRange(minValue: 110.0, maxValue: 120.0))],
                                                                                                                           timeZone: TimeZone.current)!,
                                                                                      override: GlucoseRangeSchedule.Override(value: DoubleRange(minValue: 105.0, maxValue: 115.0),
                                                                                                                              start: Date(),
                                                                                                                              end: Date().addingTimeInterval(.minutes(30))))
        let predictedGlucose = [PredictedGlucoseValue(startDate: Date().addingTimeInterval(.minutes(5)),
                                                      quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.4)),
                                PredictedGlucoseValue(startDate: Date().addingTimeInterval(.minutes(10)),
                                                      quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 125.6)),
                                PredictedGlucoseValue(startDate: Date().addingTimeInterval(.minutes(15)),
                                                      quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 127.8))]
        let predictedGlucoseIncludingPendingInsulin = [PredictedGlucoseValue(startDate: Date().addingTimeInterval(.minutes(5)),
                                                                             quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 113.4)),
                                                       PredictedGlucoseValue(startDate: Date().addingTimeInterval(.minutes(10)),
                                                                             quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 115.6)),
                                                       PredictedGlucoseValue(startDate: Date().addingTimeInterval(.minutes(15)),
                                                                             quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 117.8))]
        let lastReservoirValue = StoredDosingDecision.LastReservoirValue(startDate: Date(), unitVolume: 67.7)
        let recommendedTempBasal = StoredDosingDecision.TempBasalRecommendationWithDate(recommendation: TempBasalRecommendation(unitsPerHour: 0.15,
                                                                                                                                duration: .minutes(30)),
                                                                                        date: Date())
        let recommendedBolus = StoredDosingDecision.BolusRecommendationWithDate(recommendation: BolusRecommendation(amount: 1.2,
                                                                                                                    pendingInsulin: 0.85,
                                                                                                                    notice: .predictedGlucoseBelowTarget(minGlucose: PredictedGlucoseValue(startDate: Date(),
                                                                                                                                                                                           quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 75.5)))),
                                                                                date: Date())
        let pumpManagerStatus = PumpManagerStatus(timeZone: TimeZone.current,
                                                  device: HKDevice(name: "Device Name",
                                                                   manufacturer: "Device Manufacturer",
                                                                   model: "Device Model",
                                                                   hardwareVersion: "Device Hardware Version",
                                                                   firmwareVersion: "Device Firmware Version",
                                                                   softwareVersion: "Device Software Version",
                                                                   localIdentifier: "Device Local Identifier",
                                                                   udiDeviceIdentifier: "Device UDI Device Identifier"),
                                                  pumpBatteryChargeRemaining: 3.5,
                                                  basalDeliveryState: .initiatingTempBasal,
                                                  bolusState: .none)
        let errors: [Error] = [CarbStore.CarbStoreError.notConfigured,
                               DoseStore.DoseStoreError.configurationError,
                               LoopError.connectionError,
                               PumpManagerError.configuration(nil),
                               TestLocalizedError()]
        let storedDosingDecision = StoredDosingDecision(date: Date(),
                                                        insulinOnBoard: insulinOnBoard,
                                                        carbsOnBoard: carbsOnBoard,
                                                        scheduleOverride: scheduleOverride,
                                                        glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
                                                        glucoseTargetRangeScheduleApplyingOverrideIfActive: glucoseTargetRangeScheduleApplyingOverrideIfActive,
                                                        predictedGlucose: predictedGlucose,
                                                        predictedGlucoseIncludingPendingInsulin: predictedGlucoseIncludingPendingInsulin,
                                                        lastReservoirValue: lastReservoirValue,
                                                        recommendedTempBasal: recommendedTempBasal,
                                                        recommendedBolus: recommendedBolus,
                                                        pumpManagerStatus: pumpManagerStatus,
                                                        errors: errors,
                                                        syncIdentifier: UUID().uuidString)
        try assertStoredDosingDecisionCodable(storedDosingDecision)
    }
    
    func assertStoredDosingDecisionCodable(_ original: StoredDosingDecision) throws {
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(StoredDosingDecision.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

extension StoredDosingDecision: Equatable {
    public static func == (lhs: StoredDosingDecision, rhs: StoredDosingDecision) -> Bool {
        return lhs.date == rhs.date &&
            lhs.insulinOnBoard == rhs.insulinOnBoard &&
            lhs.carbsOnBoard == rhs.carbsOnBoard &&
            lhs.scheduleOverride == rhs.scheduleOverride &&
            lhs.glucoseTargetRangeSchedule == rhs.glucoseTargetRangeSchedule &&
            lhs.glucoseTargetRangeScheduleApplyingOverrideIfActive == rhs.glucoseTargetRangeScheduleApplyingOverrideIfActive &&
            lhs.predictedGlucose == rhs.predictedGlucose &&
            lhs.predictedGlucoseIncludingPendingInsulin == rhs.predictedGlucoseIncludingPendingInsulin &&
            lhs.lastReservoirValue == rhs.lastReservoirValue &&
            lhs.recommendedTempBasal == rhs.recommendedTempBasal &&
            lhs.recommendedBolus == rhs.recommendedBolus &&
            lhs.pumpManagerStatus == rhs.pumpManagerStatus &&
            errorsEqual(lhs.errors, rhs.errors) &&
            lhs.syncIdentifier == rhs.syncIdentifier
    }
    
    private static func errorsEqual(_ lhs: [Error]?, _ rhs: [Error]?) -> Bool {
        guard let lhs = lhs else {
            return rhs == nil
        }
        guard let rhs = rhs else {
            return false
        }
        guard lhs.count == rhs.count else {
            return false
        }
        return zip(lhs, rhs).allSatisfy { errorsEqual($0, $1) }
    }
    
    private static func errorsEqual(_ lhs: Error, _ rhs: Error) -> Bool {
        switch (lhs, rhs) {
        case (let lhs as CarbStore.CarbStoreError, let rhs as CarbStore.CarbStoreError):
            return lhs == rhs
        case (let lhs as DoseStore.DoseStoreError, let rhs as DoseStore.DoseStoreError):
            return lhs == rhs
        case (let lhs as LoopError, let rhs as LoopError):
            return lhs == rhs
        case (let lhs as PumpManagerError, let rhs as PumpManagerError):
            return lhs == rhs
        case (let lhs as LocalizedError, let rhs as LocalizedError):
            return lhs.localizedDescription == rhs.localizedDescription &&
                lhs.errorDescription == rhs.errorDescription &&
                lhs.failureReason == rhs.failureReason &&
                lhs.recoverySuggestion == rhs.recoverySuggestion &&
                lhs.helpAnchor == rhs.helpAnchor
        default:
            return lhs.localizedDescription == rhs.localizedDescription
        }
    }
}

extension StoredDosingDecision.LastReservoirValue: Equatable {
    public static func == (lhs: StoredDosingDecision.LastReservoirValue, rhs: StoredDosingDecision.LastReservoirValue) -> Bool {
        return lhs.startDate == rhs.startDate && lhs.unitVolume == rhs.unitVolume
    }
}

extension StoredDosingDecision.TempBasalRecommendationWithDate: Equatable {
    public static func == (lhs: StoredDosingDecision.TempBasalRecommendationWithDate, rhs: StoredDosingDecision.TempBasalRecommendationWithDate) -> Bool {
        return lhs.recommendation == rhs.recommendation && lhs.date == rhs.date
    }
}

extension StoredDosingDecision.BolusRecommendationWithDate: Equatable {
    public static func == (lhs: StoredDosingDecision.BolusRecommendationWithDate, rhs: StoredDosingDecision.BolusRecommendationWithDate) -> Bool {
        return lhs.recommendation == rhs.recommendation && lhs.date == rhs.date
    }
}
