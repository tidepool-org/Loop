//
//  DoseStoreTests.swift
//  LoopTests
//
//  Created by Darin Krauss on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit

class DoseStoreDoseStoreErrorCodableTests: XCTestCase {
    func testCodableConfigurationError() throws {
        try assertDoseStoreDoseStoreErrorCodable(.configurationError)
    }
    
    func testCodableInitializationErrorWithRecoverySuggestion() throws {
        try assertDoseStoreDoseStoreErrorCodable(.initializationError(description: UUID().uuidString, recoverySuggestion: UUID().uuidString))
    }
    
    func testCodableInitializationErrorWithoutRecoverySuggestion() throws {
        try assertDoseStoreDoseStoreErrorCodable(.initializationError(description: UUID().uuidString, recoverySuggestion: nil))
    }
    
    func testCodablePersistenceErrorWithRecoverySuggestion() throws {
        try assertDoseStoreDoseStoreErrorCodable(.persistenceError(description: UUID().uuidString, recoverySuggestion: UUID().uuidString))
    }
    
    func testCodablePersistenceErrorWithoutRecoverySuggestion() throws {
        try assertDoseStoreDoseStoreErrorCodable(.persistenceError(description: UUID().uuidString, recoverySuggestion: nil))
    }
    
    func testCodableFetchErrorWithRecoverySuggestion() throws {
        try assertDoseStoreDoseStoreErrorCodable(.fetchError(description: UUID().uuidString, recoverySuggestion: UUID().uuidString))
    }
    
    func testCodableFetchErrorWithoutRecoverySuggestion() throws {
        try assertDoseStoreDoseStoreErrorCodable(.fetchError(description: UUID().uuidString, recoverySuggestion: nil))
    }
    
    func assertDoseStoreDoseStoreErrorCodable(_ original: DoseStore.DoseStoreError) throws {
        let data = try PropertyListEncoder().encode(TestContainer(doseStoreError: original))
        let decoded = try PropertyListDecoder().decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.doseStoreError, original)
    }
    
    private struct TestContainer: Codable, Equatable {
        let doseStoreError: DoseStore.DoseStoreError
    }
}

extension DoseStore.DoseStoreError: Equatable {
    public static func == (lhs: DoseStore.DoseStoreError, rhs: DoseStore.DoseStoreError) -> Bool {
        switch (lhs, rhs) {
        case (.configurationError, .configurationError):
            return true
        case (.initializationError(let lhsDescription, let lhsRecoverySuggestion), .initializationError(let rhsDescription, let rhsRecoverySuggestion)),
             (.persistenceError(let lhsDescription, let lhsRecoverySuggestion), .persistenceError(let rhsDescription, let rhsRecoverySuggestion)),
             (.fetchError(let lhsDescription, let lhsRecoverySuggestion), .fetchError(let rhsDescription, let rhsRecoverySuggestion)):
            return lhsDescription == rhsDescription && lhsRecoverySuggestion == rhsRecoverySuggestion
        default:
            return false
        }
    }
}
