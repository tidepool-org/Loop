//
//  MockSettingsProvider.swift
//  LoopTests
//
//  Created by Pete Schwamb on 11/28/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit
@testable import Loop

struct MockSettingsProvider: SettingsProvider {

    var basalHistory: [AbsoluteScheduleValue<Double>]?
    func getBasalHistory(startDate: Date, endDate: Date) async throws -> [AbsoluteScheduleValue<Double>] {
        return basalHistory ?? settings.basalRateSchedule?.between(start: startDate, end: endDate) ?? []
    }
    
    var carbRatioHistory: [AbsoluteScheduleValue<Double>]?
    func getCarbRatioHistory(startDate: Date, endDate: Date) async throws -> [AbsoluteScheduleValue<Double>] {
        return carbRatioHistory ?? settings.carbRatioSchedule?.between(start: startDate, end: endDate) ?? []
    }
    
    var insulinSensitivityHistory: [AbsoluteScheduleValue<HKQuantity>]?
    func getInsulinSensitivityHistory(startDate: Date, endDate: Date) async throws -> [AbsoluteScheduleValue<HKQuantity>] {
        return insulinSensitivityHistory ?? settings.insulinSensitivitySchedule?.quantitiesBetween(start: startDate, end: endDate) ?? []
    }
    
    var targetRangeHistory: [AbsoluteScheduleValue<ClosedRange<HKQuantity>>]?
    func getTargetRangeHistory(startDate: Date, endDate: Date) async throws -> [AbsoluteScheduleValue<ClosedRange<HKQuantity>>] {
        return targetRangeHistory ?? settings.glucoseTargetRangeSchedule?.quantityBetween(start: startDate, end: endDate) ?? []
    }
    
    var dosingLimits = DosingLimits()
    func getDosingLimits(at date: Date) async throws -> DosingLimits {
        return dosingLimits
    }

    var settings: StoredSettings
}
