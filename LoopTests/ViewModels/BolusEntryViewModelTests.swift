//
//  BolusEntryViewModelTests.swift
//  LoopTests
//
//  Created by Rick Pasetto on 9/28/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopCore
import LoopKit
import XCTest
@testable import Loop

struct MockLoopState: LoopState {
    
    var carbsOnBoard: CarbValue?
    
    var error: Error?
    
    var insulinCounteractionEffects: [GlucoseEffectVelocity] = []
    
    var predictedGlucose: [PredictedGlucoseValue]?
    
    var predictedGlucoseIncludingPendingInsulin: [PredictedGlucoseValue]?
    
    var recommendedTempBasal: (recommendation: TempBasalRecommendation, date: Date)?
    
    var recommendedBolus: (recommendation: BolusRecommendation, date: Date)?
    
    var retrospectiveGlucoseDiscrepancies: [GlucoseChange]?
    
    var totalRetrospectiveCorrection: HKQuantity?
    
    var predictGlucoseValueResult: [PredictedGlucoseValue] = []
    func predictGlucose(using inputs: PredictionInputEffect, potentialBolus: DoseEntry?, potentialCarbEntry: NewCarbEntry?, replacingCarbEntry replacedCarbEntry: StoredCarbEntry?, includingPendingInsulin: Bool) throws -> [PredictedGlucoseValue] {
        return predictGlucoseValueResult
    }

    func predictGlucoseFromManualGlucose(_ glucose: NewGlucoseSample, potentialBolus: DoseEntry?, potentialCarbEntry: NewCarbEntry?, replacingCarbEntry replacedCarbEntry: StoredCarbEntry?, includingPendingInsulin: Bool) throws -> [PredictedGlucoseValue] {
        return predictGlucoseValueResult
    }
    
    var bolusRecommendationResult: BolusRecommendation?
    func recommendBolus(consideringPotentialCarbEntry potentialCarbEntry: NewCarbEntry?, replacingCarbEntry replacedCarbEntry: StoredCarbEntry?) throws -> BolusRecommendation? {
        return bolusRecommendationResult
    }
    
    func recommendBolusForManualGlucose(_ glucose: NewGlucoseSample, consideringPotentialCarbEntry potentialCarbEntry: NewCarbEntry?, replacingCarbEntry replacedCarbEntry: StoredCarbEntry?) throws -> BolusRecommendation? {
        return bolusRecommendationResult
    }
}

struct MockInsulinModel: InsulinModel {
    func percentEffectRemaining(at time: TimeInterval) -> Double {
        0
    }
    
    var effectDuration: TimeInterval = 0

    var delay: TimeInterval = 0
    
    var debugDescription: String = ""
}

class BolusEntryViewModelTests: XCTestCase {
    
    class MockBolusEntryViewModelDelegate: BolusEntryViewModelDelegate {
        var loopStateCallBlock: ((LoopState) -> Void)?
        func withLoopState(do block: @escaping (LoopState) -> Void) {
            loopStateCallBlock = block
        }
        
        func addGlucose(_ samples: [NewGlucoseSample], completion: ((Result<[GlucoseValue]>) -> Void)?) {
            
        }
        
        func addCarbEntry(_ carbEntry: NewCarbEntry, replacing replacingEntry: StoredCarbEntry?, completion: @escaping (Result<Void>) -> Void) {
            
        }
        
        func enactBolus(units: Double, at startDate: Date, completion: @escaping (Error?) -> Void) {
            
        }
        
        func getCachedGlucoseSamples(start: Date, end: Date?, completion: @escaping ([StoredGlucoseSample]) -> Void) {
            
        }
        
        func insulinOnBoard(at date: Date, completion: @escaping (DoseStoreResult<InsulinValue>) -> Void) {
            
        }
        
        func carbsOnBoard(at date: Date, effectVelocities: [GlucoseEffectVelocity]?, completion: @escaping (CarbStoreResult<CarbValue>) -> Void) {
            
        }
        
        func ensureCurrentPumpData(completion: @escaping () -> Void) {
            
        }
        
        var isGlucoseDataStale: Bool = false
        
        var isPumpDataStale: Bool = false
        
        var isPumpConfigured: Bool = true
        
        var preferredGlucoseUnit: HKUnit? = .milligramsPerDeciliter
        
        var insulinModel: InsulinModel? = MockInsulinModel()
        
        var settings: LoopSettings = LoopSettings()
    }
    
    var bolusEntryViewModel: BolusEntryViewModel!
    var delegate: BolusEntryViewModelDelegate!
    var now: Date = Date.distantFuture

    override func setUpWithError() throws {
        now = Date.distantFuture
        delegate = MockBolusEntryViewModelDelegate()
        bolusEntryViewModel = BolusEntryViewModel(delegate: delegate,
                                                  now: { self.now },
                                                  screenWidth: 512,
                                                  originalCarbEntry: nil,
                                                  potentialCarbEntry: nil,
                                                  selectedCarbAbsorptionTimeEmoji: nil)
    }

    override func tearDownWithError() throws {
    }

    func testInitialConditions() throws {
        XCTAssertEqual(0, bolusEntryViewModel.glucoseValues.count)
        XCTAssertEqual(0, bolusEntryViewModel.predictedGlucoseValues.count)
        XCTAssertEqual(.milligramsPerDeciliter, bolusEntryViewModel.glucoseUnit)
        XCTAssertNil(bolusEntryViewModel.activeCarbs)
        XCTAssertNil(bolusEntryViewModel.activeInsulin)
        XCTAssertNil(bolusEntryViewModel.targetGlucoseSchedule)
        XCTAssertNil(bolusEntryViewModel.preMealOverride)
        XCTAssertNil(bolusEntryViewModel.scheduleOverride)
       
        XCTAssertFalse(bolusEntryViewModel.isManualGlucoseEntryEnabled)

        XCTAssertNil(bolusEntryViewModel.enteredManualGlucose)
        XCTAssertNil(bolusEntryViewModel.recommendedBolus)
        XCTAssertEqual(HKQuantity(unit: .internationalUnit(), doubleValue: 0), bolusEntryViewModel.enteredBolus)

        XCTAssertNil(bolusEntryViewModel.activeAlert)
        XCTAssertNil(bolusEntryViewModel.activeNotice)

        XCTAssertFalse(bolusEntryViewModel.isRefreshingPump)
    }
    
    func testChartDateInterval() throws {
        // TODO: Test different screen widths
        // TODO: Test different insulin models
        // TODO: Test different chart history settings
        let expected = DateInterval(start: now - .hours(9), duration: .hours(8))
        XCTAssertEqual(expected, bolusEntryViewModel.chartDateInterval)
    }

}
