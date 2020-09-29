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

class MockLoopState: LoopState {
    
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
    var bolusRecommendationError: Error?
    var consideringPotentialCarbEntryPassed: NewCarbEntry??
    var replacingCarbEntryPassed: StoredCarbEntry??
    func recommendBolus(consideringPotentialCarbEntry potentialCarbEntry: NewCarbEntry?, replacingCarbEntry replacedCarbEntry: StoredCarbEntry?) throws -> BolusRecommendation? {
        consideringPotentialCarbEntryPassed = potentialCarbEntry
        replacingCarbEntryPassed = replacedCarbEntry
        if let error = bolusRecommendationError { throw error }
        return bolusRecommendationResult
    }
    
    func recommendBolusForManualGlucose(_ glucose: NewGlucoseSample, consideringPotentialCarbEntry potentialCarbEntry: NewCarbEntry?, replacingCarbEntry replacedCarbEntry: StoredCarbEntry?) throws -> BolusRecommendation? {
        consideringPotentialCarbEntryPassed = potentialCarbEntry
        replacingCarbEntryPassed = replacedCarbEntry
        if let error = bolusRecommendationError { throw error }
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

struct MockGlucoseValue: GlucoseValue {
    var quantity: HKQuantity
    var startDate: Date
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
        
        var cachedGlucoseSamplesResponse: [StoredGlucoseSample] = []
        func getCachedGlucoseSamples(start: Date, end: Date?, completion: @escaping ([StoredGlucoseSample]) -> Void) {
            completion(cachedGlucoseSamplesResponse)
        }
        
        func insulinOnBoard(at date: Date, completion: @escaping (DoseStoreResult<InsulinValue>) -> Void) {
            
        }
        
        var carbsOnBoardResult: CarbStoreResult<CarbValue>?
        func carbsOnBoard(at date: Date, effectVelocities: [GlucoseEffectVelocity]?, completion: @escaping (CarbStoreResult<CarbValue>) -> Void) {
            if let carbsOnBoardResult = carbsOnBoardResult {
                completion(carbsOnBoardResult)
            }
        }
        
        var ensureCurrentPumpDataCompletion: (() -> Void)?
        func ensureCurrentPumpData(completion: @escaping () -> Void) {
            ensureCurrentPumpDataCompletion = completion
        }
        
        var isGlucoseDataStale: Bool = false
        
        var isPumpDataStale: Bool = false
        
        var isPumpConfigured: Bool = true
        
        var preferredGlucoseUnit: HKUnit? = .milligramsPerDeciliter
        
        var insulinModel: InsulinModel? = MockInsulinModel()
        
        var settings: LoopSettings = LoopSettings()
    }
    
    static let now = Date.distantFuture
    static let exampleStartDate = Date.distantFuture - .hours(2)
    static let exampleEndDate = Date.distantFuture - .hours(1)
    static let exampleGlucoseValue = MockGlucoseValue(quantity: exampleManualGlucoseQuantity, startDate: exampleStartDate)
    static let exampleManualGlucoseQuantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.4)
    static let exampleManualGlucoseSample =
        HKQuantitySample(type: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
                         quantity: exampleManualGlucoseQuantity,
                         start: exampleStartDate,
                         end: exampleEndDate)
    
    static let exampleCGMGlucoseQuantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 100.4)
    static let exampleCGMGlucoseSample =
        HKQuantitySample(type: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
                         quantity: exampleCGMGlucoseQuantity,
                         start: exampleStartDate,
                         end: exampleEndDate)

    static let exampleCarbQuantity = HKQuantity(unit: .gram(), doubleValue: 234.5)
    
    var bolusEntryViewModel: BolusEntryViewModel!
    var delegate: MockBolusEntryViewModelDelegate!
    var now: Date = BolusEntryViewModelTests.now
    
    let mockOriginalCarbEntry = StoredCarbEntry(uuid: UUID(), provenanceIdentifier: "provenanceIdentifier", syncIdentifier: "syncIdentifier", syncVersion: 0, startDate: Date(), quantity: BolusEntryViewModelTests.exampleCarbQuantity, foodType: "foodType", absorptionTime: 1, createdByCurrentApp: true, userCreatedDate: Date(), userUpdatedDate: Date())
    let mockPotentialCarbEntry = NewCarbEntry(quantity: BolusEntryViewModelTests.exampleCarbQuantity, startDate: Date(), foodType: "foodType", absorptionTime: 1)
    
    let queue = DispatchQueue(label: "BolusEntryViewModelTests")
    
    override func setUpWithError() throws {
        now = Date.distantFuture
        delegate = MockBolusEntryViewModelDelegate()
        bolusEntryViewModel = BolusEntryViewModel(delegate: delegate,
                                                  now: { self.now },
                                                  screenWidth: 512,
                                                  debounceIntervalMilliseconds: 0,
                                                  originalCarbEntry: mockOriginalCarbEntry,
                                                  potentialCarbEntry: mockPotentialCarbEntry,
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

    func testUpdateDisableManualGlucoseEntryIfNecessary() throws {
        bolusEntryViewModel.isManualGlucoseEntryEnabled = true
        bolusEntryViewModel.enteredManualGlucose = Self.exampleManualGlucoseQuantity
        try triggerLoopStateUpdated(with: MockLoopState())
        XCTAssertFalse(bolusEntryViewModel.isManualGlucoseEntryEnabled)
        XCTAssertNil(bolusEntryViewModel.enteredManualGlucose)
        XCTAssertEqual(.glucoseNoLongerStale, bolusEntryViewModel.activeAlert)
    }
    
    func testUpdateGlucoseValues() throws {
        XCTAssertEqual(0, bolusEntryViewModel.glucoseValues.count)
        try triggerLoopStateUpdatedWithDataAndWait()
        XCTAssertEqual(1, bolusEntryViewModel.glucoseValues.count)
        XCTAssertEqual([100.4], bolusEntryViewModel.glucoseValues.map {
            return $0.quantity.doubleValue(for: .milligramsPerDeciliter)
        })
    }
    
    func testUpdateGlucoseValuesWithManual() throws {
        XCTAssertEqual(0, bolusEntryViewModel.glucoseValues.count)
        bolusEntryViewModel.enteredManualGlucose = Self.exampleManualGlucoseQuantity
        try triggerLoopStateUpdatedWithDataAndWait()
        XCTAssertEqual([100.4, 123.4], bolusEntryViewModel.glucoseValues.map {
            return $0.quantity.doubleValue(for: .milligramsPerDeciliter)
        })
    }
    
    func testUpdatePredictedGlucoseValues() throws {
        //TODO
    }
    
    func testUpdatePredictedGlucoseValuesWithManual() throws {
        //TODO
    }
    
    func testUpdateCarbsOnBoard() throws {
        delegate.carbsOnBoardResult = .success(CarbValue(startDate: Self.exampleStartDate, endDate: Self.exampleEndDate, quantity: Self.exampleCarbQuantity))
        XCTAssertNil(bolusEntryViewModel.activeCarbs)
        try triggerLoopStateUpdatedWithDataAndWait()
        XCTAssertEqual(Self.exampleCarbQuantity, bolusEntryViewModel.activeCarbs)
    }
    
    func testUpdateCarbsOnBoardFailure() throws {
        delegate.carbsOnBoardResult = .failure(CarbStore.CarbStoreError.notConfigured)
        try triggerLoopStateUpdatedWithDataAndWait()
        XCTAssertNil(bolusEntryViewModel.activeCarbs)
    }

    func testUpdateRecommendedBolusNoNotice() throws {
        let mockState = MockLoopState()
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        mockState.bolusRecommendationResult = BolusRecommendation(amount: 1.234, pendingInsulin: 4.321)
        try triggerLoopStateUpdatedWithDataAndWait(with: mockState)
        XCTAssertTrue(bolusEntryViewModel.isBolusRecommended)
        let recommendedBolus = bolusEntryViewModel.recommendedBolus
        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(mockState.bolusRecommendationResult?.amount, recommendedBolus?.doubleValue(for: .internationalUnit()))
        let consideringPotentialCarbEntryPassed = try XCTUnwrap(mockState.consideringPotentialCarbEntryPassed)
        XCTAssertEqual(mockPotentialCarbEntry, consideringPotentialCarbEntryPassed)
        let replacingCarbEntryPassed = try XCTUnwrap(mockState.replacingCarbEntryPassed)
        XCTAssertEqual(mockOriginalCarbEntry, replacingCarbEntryPassed)
        XCTAssertNil(bolusEntryViewModel.activeNotice)
    }
            
    func testUpdateRecommendedBolusWithNotice() throws {
        let mockState = MockLoopState()
        delegate.settings.suspendThreshold = GlucoseThreshold(unit: .milligramsPerDeciliter, value: Self.exampleCGMGlucoseQuantity.doubleValue(for: .milligramsPerDeciliter))
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        mockState.bolusRecommendationResult = BolusRecommendation(amount: 1.234, pendingInsulin: 4.321, notice: BolusRecommendationNotice.glucoseBelowSuspendThreshold(minGlucose: Self.exampleGlucoseValue))
        try triggerLoopStateUpdatedWithDataAndWait(with: mockState)
        XCTAssertTrue(bolusEntryViewModel.isBolusRecommended)
        let recommendedBolus = bolusEntryViewModel.recommendedBolus
        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(mockState.bolusRecommendationResult?.amount, recommendedBolus?.doubleValue(for: .internationalUnit()))
        XCTAssertEqual(BolusEntryViewModel.Notice.predictedGlucoseBelowSuspendThreshold(suspendThreshold: Self.exampleCGMGlucoseQuantity), bolusEntryViewModel.activeNotice)
    }
    
    func testUpdateRecommendedBolusWithNoticeMissingSuspendThreshold() throws {
        let mockState = MockLoopState()
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        mockState.bolusRecommendationResult = BolusRecommendation(amount: 1.234, pendingInsulin: 4.321, notice: BolusRecommendationNotice.glucoseBelowSuspendThreshold(minGlucose: Self.exampleGlucoseValue))
        try triggerLoopStateUpdatedWithDataAndWait(with: mockState)
        XCTAssertTrue(bolusEntryViewModel.isBolusRecommended)
        let recommendedBolus = bolusEntryViewModel.recommendedBolus
        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(mockState.bolusRecommendationResult?.amount, recommendedBolus?.doubleValue(for: .internationalUnit()))
        XCTAssertNil(bolusEntryViewModel.activeNotice)
    }

    func testUpdateRecommendedBolusWithOtherNotice() throws {
        let mockState = MockLoopState()
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        mockState.bolusRecommendationResult = BolusRecommendation(amount: 1.234, pendingInsulin: 4.321, notice: BolusRecommendationNotice.currentGlucoseBelowTarget(glucose: Self.exampleGlucoseValue))
        try triggerLoopStateUpdatedWithDataAndWait(with: mockState)
        XCTAssertTrue(bolusEntryViewModel.isBolusRecommended)
        let recommendedBolus = bolusEntryViewModel.recommendedBolus
        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(mockState.bolusRecommendationResult?.amount, recommendedBolus?.doubleValue(for: .internationalUnit()))
        XCTAssertNil(bolusEntryViewModel.activeNotice)
    }
        
    func testUpdateRecommendedBolusThrowsMissingDataError() throws {
        let mockState = MockLoopState()
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        mockState.bolusRecommendationError = LoopError.missingDataError(.glucose)
        try triggerLoopStateUpdatedWithDataAndWait(with: mockState)
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        let recommendedBolus = bolusEntryViewModel.recommendedBolus
        XCTAssertNil(recommendedBolus)
        XCTAssertEqual(.staleGlucoseData, bolusEntryViewModel.activeNotice)
    }
    
    func testUpdateRecommendedBolusThrowsPumpDataTooOld() throws {
        let mockState = MockLoopState()
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        mockState.bolusRecommendationError = LoopError.pumpDataTooOld(date: now)
        try triggerLoopStateUpdatedWithDataAndWait(with: mockState)
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        let recommendedBolus = bolusEntryViewModel.recommendedBolus
        XCTAssertNil(recommendedBolus)
        XCTAssertEqual(.stalePumpData, bolusEntryViewModel.activeNotice)
    }

    func testUpdateRecommendedBolusThrowsOtherError() throws {
        let mockState = MockLoopState()
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        mockState.bolusRecommendationError = LoopError.invalidData(details: "")
        try triggerLoopStateUpdatedWithDataAndWait(with: mockState)
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        let recommendedBolus = bolusEntryViewModel.recommendedBolus
        XCTAssertNil(recommendedBolus)
        XCTAssertNil(bolusEntryViewModel.activeNotice)
    }
    
    func testUpdateRecommendedBolusWithManual() throws {
        let mockState = MockLoopState()
        bolusEntryViewModel.enteredManualGlucose = Self.exampleManualGlucoseQuantity
        XCTAssertFalse(bolusEntryViewModel.isBolusRecommended)
        mockState.bolusRecommendationResult = BolusRecommendation(amount: 1.234, pendingInsulin: 4.321)
        try triggerLoopStateUpdatedWithDataAndWait(with: mockState)
        XCTAssertTrue(bolusEntryViewModel.isBolusRecommended)
        let recommendedBolus = bolusEntryViewModel.recommendedBolus
        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(mockState.bolusRecommendationResult?.amount, recommendedBolus?.doubleValue(for: .internationalUnit()))
        let consideringPotentialCarbEntryPassed = try XCTUnwrap(mockState.consideringPotentialCarbEntryPassed)
        XCTAssertEqual(mockPotentialCarbEntry, consideringPotentialCarbEntryPassed)
        let replacingCarbEntryPassed = try XCTUnwrap(mockState.replacingCarbEntryPassed)
        XCTAssertEqual(mockOriginalCarbEntry, replacingCarbEntryPassed)
        XCTAssertNil(bolusEntryViewModel.activeNotice)
    }

    func testRecommendedBolusClearsEnteredBolus() throws {
        bolusEntryViewModel.enteredBolus = HKQuantity(unit: .internationalUnit(), doubleValue: 1.0)
        let mockState = MockLoopState()
        mockState.bolusRecommendationResult = BolusRecommendation(amount: 1.234, pendingInsulin: 4.321)
        try triggerLoopStateUpdatedWithDataAndWait(with: mockState)
        XCTAssertEqual(HKQuantity(unit: .internationalUnit(), doubleValue: 0.0), bolusEntryViewModel.enteredBolus)
    }

    func testUpdateDoesNotRefreshPumpIfDataIsFresh() throws {
        XCTAssertFalse(bolusEntryViewModel.isRefreshingPump)
        try triggerLoopStateUpdatedWithDataAndWait()
        XCTAssertFalse(bolusEntryViewModel.isRefreshingPump)
        XCTAssertNil(delegate.ensureCurrentPumpDataCompletion)
    }

    func testUpdateIsRefreshingPump() throws {
        delegate.isPumpDataStale = true
        XCTAssertFalse(bolusEntryViewModel.isRefreshingPump)
        try triggerLoopStateUpdatedWithDataAndWait()
        XCTAssertTrue(bolusEntryViewModel.isRefreshingPump)
        let completion = try XCTUnwrap(delegate.ensureCurrentPumpDataCompletion)
        completion()
        // Need to once again trigger loop state
        try triggerLoopStateResult(with: MockLoopState())
        // then wait on main again (sigh)
        waitOnMain()
        XCTAssertFalse(bolusEntryViewModel.isRefreshingPump)
    }

    // MARK: utilities
    
    let timeout = 1.0
    
    func triggerLoopStateUpdatedWithDataAndWait(with state: LoopState = MockLoopState(), function: String = #function) throws {
        delegate.cachedGlucoseSamplesResponse = [StoredGlucoseSample(sample: Self.exampleCGMGlucoseSample)]
        try triggerLoopStateUpdated(with: state)
        waitOnMain()
    }
    
    func triggerLoopStateUpdated(with state: LoopState, function: String = #function) throws {
        NotificationCenter.default.post(name: .LoopDataUpdated, object: nil)
        try triggerLoopStateResult(with: state, function: function)
    }
    
    func triggerLoopStateResult(with state: LoopState, function: String = #function) throws {
        let exp = expectation(description: function)
        let block = try XCTUnwrap(delegate.loopStateCallBlock)
        queue.async {
            block(state)
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
    }
    
    func waitOnMain(for interval: TimeInterval, function: String = #function) {
        let exp = expectation(description: function)
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
    }
}

extension TimeInterval {
    static func milliseconds(_ milliseconds: Double) -> TimeInterval {
        return milliseconds / 1000
    }
}
