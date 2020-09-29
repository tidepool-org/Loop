//
//  SimpleBolusCalculatorTests.swift
//  LoopTests
//
//  Created by Pete Schwamb on 9/28/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

import XCTest
import HealthKit
import LoopKit

@testable import Loop

class SimpleBolusCalculatorTests: XCTestCase {
    
    func testMealRecommendation() {
        let carbs = HKQuantity(unit: .gram(), doubleValue: 40)
        let activeInsulin = HKQuantity(unit: .internationalUnit(), doubleValue: 0)
        let carbRatioSchedule = CarbRatioSchedule(unit: .gram(), dailyItems: [RepeatingScheduleValue(startTime: 0, value: 10)])!
        let correctionRange = DoubleRange(minValue: 100.0, maxValue: 110.0)
        let correctionRangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: correctionRange)])!
        let sensitivitySchedule = InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 80)])!
        let recommendation = SimpleBolusCalculator.recommendedInsulin(
            mealCarbs: carbs,
            manualGlucose: nil,
            activeInsulin: activeInsulin,
            carbRatioSchedule: carbRatioSchedule,
            correctionRangeSchedule: correctionRangeSchedule,
            sensitivitySchedule: sensitivitySchedule)
        
        XCTAssertEqual(4.0, recommendation.doubleValue(for: .internationalUnit()))
    }
    
    func testCorrectionRecommendation() {
        let activeInsulin = HKQuantity(unit: .internationalUnit(), doubleValue: 0)
        let carbRatioSchedule = CarbRatioSchedule(unit: .gram(), dailyItems: [RepeatingScheduleValue(startTime: 0, value: 10)])!
        let correctionRange = DoubleRange(minValue: 100.0, maxValue: 110.0)
        let correctionRangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: correctionRange)])!
        let sensitivitySchedule = InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 80)])!
        let glucose = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 180)
        let recommendation = SimpleBolusCalculator.recommendedInsulin(
            mealCarbs: nil,
            manualGlucose: glucose,
            activeInsulin: activeInsulin,
            carbRatioSchedule: carbRatioSchedule,
            correctionRangeSchedule: correctionRangeSchedule,
            sensitivitySchedule: sensitivitySchedule)
        
        XCTAssertEqual(0.94, recommendation.doubleValue(for: .internationalUnit()), accuracy: 0.01)
    }
    
    func testCorrectionRecommendationWithIOB() {
        let activeInsulin = HKQuantity(unit: .internationalUnit(), doubleValue: 10)
        let carbRatioSchedule = CarbRatioSchedule(unit: .gram(), dailyItems: [RepeatingScheduleValue(startTime: 0, value: 10)])!
        let correctionRange = DoubleRange(minValue: 100.0, maxValue: 110.0)
        let correctionRangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: correctionRange)])!
        let sensitivitySchedule = InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 80)])!
        let glucose = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 180)
        let recommendation = SimpleBolusCalculator.recommendedInsulin(
            mealCarbs: nil,
            manualGlucose: glucose,
            activeInsulin: activeInsulin,
            carbRatioSchedule: carbRatioSchedule,
            correctionRangeSchedule: correctionRangeSchedule,
            sensitivitySchedule: sensitivitySchedule)
        
        XCTAssertEqual(0.0, recommendation.doubleValue(for: .internationalUnit()), accuracy: 0.01)
    }

    func testCorrectionRecommendationWhenInRange() {
        let activeInsulin = HKQuantity(unit: .internationalUnit(), doubleValue: 0)
        let carbRatioSchedule = CarbRatioSchedule(unit: .gram(), dailyItems: [RepeatingScheduleValue(startTime: 0, value: 10)])!
        let correctionRange = DoubleRange(minValue: 100.0, maxValue: 110.0)
        let correctionRangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: correctionRange)])!
        let sensitivitySchedule = InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 80)])!
        let glucose = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 110)
        let recommendation = SimpleBolusCalculator.recommendedInsulin(
            mealCarbs: nil,
            manualGlucose: glucose,
            activeInsulin: activeInsulin,
            carbRatioSchedule: carbRatioSchedule,
            correctionRangeSchedule: correctionRangeSchedule,
            sensitivitySchedule: sensitivitySchedule)
        
        XCTAssertEqual(0.0, recommendation.doubleValue(for: .internationalUnit()), accuracy: 0.01)
    }

    func testCorrectionAndCarbsRecommendationWhenBelowRange() {
        let carbs = HKQuantity(unit: .gram(), doubleValue: 40)
        let activeInsulin = HKQuantity(unit: .internationalUnit(), doubleValue: 0)
        let carbRatioSchedule = CarbRatioSchedule(unit: .gram(), dailyItems: [RepeatingScheduleValue(startTime: 0, value: 10)])!
        let correctionRange = DoubleRange(minValue: 100.0, maxValue: 110.0)
        let correctionRangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: correctionRange)])!
        let sensitivitySchedule = InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 80)])!
        let glucose = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 70)
        let recommendation = SimpleBolusCalculator.recommendedInsulin(
            mealCarbs: carbs,
            manualGlucose: glucose,
            activeInsulin: activeInsulin,
            carbRatioSchedule: carbRatioSchedule,
            correctionRangeSchedule: correctionRangeSchedule,
            sensitivitySchedule: sensitivitySchedule)
        
        XCTAssertEqual(3.56, recommendation.doubleValue(for: .internationalUnit()), accuracy: 0.01)
    }


}
