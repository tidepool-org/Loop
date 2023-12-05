//
//  ManualEntryDoseViewModelTests.swift
//  LoopTests
//
//  Created by Pete Schwamb on 1/2/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopCore
import LoopKit
import XCTest
@testable import Loop

@MainActor
class ManualEntryDoseViewModelTests: XCTestCase {

    static let now = Date.distantFuture
    
    var now: Date = BolusEntryViewModelTests.now

    var manualEntryDoseViewModel: ManualEntryDoseViewModel!

    static let exampleBolusQuantity = HKQuantity(unit: .internationalUnit(), doubleValue: 1.0)

    static let noBolus = HKQuantity(unit: .internationalUnit(), doubleValue: 0.0)
    
    var authenticateOverrideCompletion: ((Swift.Result<Void, Error>) -> Void)?
    private func authenticateOverride(_ message: String, _ completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        authenticateOverrideCompletion = completion
    }
    
    var saveAndDeliverSuccess = false

    fileprivate var delegate: MockManualEntryDoseViewModelDelegate!
    
    static let mockUUID = UUID()
    let mockUUID = ManualEntryDoseViewModelTests.mockUUID.uuidString

    override func setUpWithError() throws {
        now = Self.now
        delegate = MockManualEntryDoseViewModelDelegate()
        saveAndDeliverSuccess = false
        setUpViewModel()
    }

    func setUpViewModel() {
        manualEntryDoseViewModel = ManualEntryDoseViewModel(delegate: delegate,
                                                  now: { self.now },
                                                  debounceIntervalMilliseconds: 0,
                                                  uuidProvider: { self.mockUUID },
                                                  timeZone: TimeZone(abbreviation: "GMT")!)
        manualEntryDoseViewModel.authenticate = authenticateOverride
    }

    func testDoseLogging() throws {
        XCTAssertEqual(.novolog, manualEntryDoseViewModel.selectedInsulinType)
        manualEntryDoseViewModel.enteredBolus = Self.exampleBolusQuantity
        
        try saveAndDeliver(ManualEntryDoseViewModelTests.exampleBolusQuantity)
        XCTAssertEqual(delegate.manualEntryBolusUnits, Self.exampleBolusQuantity.doubleValue(for: .internationalUnit()))
        XCTAssertEqual(delegate.manuallyEnteredDoseInsulinType, .novolog)
    }
    
    private func saveAndDeliver(_ bolus: HKQuantity, file: StaticString = #file, line: UInt = #line) throws {
        manualEntryDoseViewModel.enteredBolus = bolus
        manualEntryDoseViewModel.saveManualDose { self.saveAndDeliverSuccess = true }
        if bolus != ManualEntryDoseViewModelTests.noBolus {
            let authenticateOverrideCompletion = try XCTUnwrap(self.authenticateOverrideCompletion, file: file, line: line)
            authenticateOverrideCompletion(.success(()))
        }
    }
}

fileprivate class MockManualEntryDoseViewModelDelegate: ManualDoseViewModelDelegate {
    var pumpInsulinType: LoopKit.InsulinType?
   
    var manualEntryBolusUnits: Double?
    var manualEntryDoseStartDate: Date?
    var manuallyEnteredDoseInsulinType: InsulinType?

    func addManuallyEnteredDose(startDate: Date, units: Double, insulinType: InsulinType?) {
        manualEntryBolusUnits = units
        manualEntryDoseStartDate = startDate
        manuallyEnteredDoseInsulinType = insulinType
    }
    
    func insulinActivityDuration(for type: LoopKit.InsulinType?) -> TimeInterval {
        return InsulinMath.defaultInsulinActivityDuration
    }
    
    var algorithmDisplayState = AlgorithmDisplayState()

    var settings = StoredSettings()

    var scheduleOverride: TemporaryScheduleOverride?

}

