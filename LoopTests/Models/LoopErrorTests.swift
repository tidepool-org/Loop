//
//  LoopErrorTests.swift
//  LoopTests
//
//  Created by Darin Krauss on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit

@testable import Loop

class LoopErrorCodableTests: XCTestCase {
    func testCodableBolusCommand() throws {
        try assertLoopErrorCodable(.bolusCommand(SetBolusError.uncertain(TestLocalizedError())))
    }
    
    func testCodableConfigurationError() throws {
        try assertLoopErrorCodable(.configurationError(.pumpManager))
    }
    
    func testCodableConnectionError() throws {
        try assertLoopErrorCodable(.connectionError)
    }
    
    func testCodableMissingDataError() throws {
        try assertLoopErrorCodable(.missingDataError(.glucose))
    }
    
    func testCodableGlucoseTooOld() throws {
        try assertLoopErrorCodable(.glucoseTooOld(date: Date()))
    }
    
    func testCodablePumpDataTooOld() throws {
        try assertLoopErrorCodable(.pumpDataTooOld(date: Date()))
    }
    
    func testCodableRecommendationExpired() throws {
        try assertLoopErrorCodable(.recommendationExpired(date: Date()))
    }
    
    func testCodableInvalidDate() throws {
        try assertLoopErrorCodable(.invalidData(details: UUID().uuidString))
    }
    
    func assertLoopErrorCodable(_ original: LoopError) throws {
        let data = try PropertyListEncoder().encode(TestContainer(loopError: original))
        let decoded = try PropertyListDecoder().decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.loopError, original)
    }
    
    private struct TestContainer: Codable, Equatable {
        let loopError: LoopError
    }
}

extension LoopError: Equatable {
    public static func == (lhs: LoopError, rhs: LoopError) -> Bool {
        switch (lhs, rhs) {
        case (.bolusCommand(let lhsSetBolusError), .bolusCommand(let rhsSetBolusError)):
            return lhsSetBolusError == rhsSetBolusError
        case (.configurationError(let lhsConfigurationErrorDetail), .configurationError(let rhsConfigurationErrorDetail)):
            return lhsConfigurationErrorDetail == rhsConfigurationErrorDetail
        case (.connectionError, .connectionError):
            return true
        case (.missingDataError(let lhsMissingDataErrorDetail), .missingDataError(let rhsMissingDataErrorDetail)):
            return lhsMissingDataErrorDetail == rhsMissingDataErrorDetail
        case (.glucoseTooOld(let lhsDate), .glucoseTooOld(let rhsDate)),
             (.pumpDataTooOld(let lhsDate), .pumpDataTooOld(let rhsDate)),
             (.recommendationExpired(let lhsDate), .recommendationExpired(let rhsDate)):
            return lhsDate == rhsDate
        case (.invalidData(let lhsDetails), .invalidData(let rhsDetails)):
            return lhsDetails == rhsDetails
        default:
            return false
        }
    }
}
