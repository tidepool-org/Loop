//
//  CarbStoreTests.swift
//  LoopTests
//
//  Created by Darin Krauss on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit

class CarbStoreErrorCodableTests: XCTestCase {
    func testCodableConfigurationError() throws {
        try assertCarbStoreErrorCodable(.notConfigured)
    }

    func testCodableInitializationError() throws {
        try assertCarbStoreErrorCodable(.healthStoreError(TestLocalizedError()))
    }

    func testCodablePersistenceError() throws {
        try assertCarbStoreErrorCodable(.unauthorized)
    }

    func testCodableFetchError() throws {
        try assertCarbStoreErrorCodable(.noData)
    }

    func assertCarbStoreErrorCodable(_ original: CarbStore.CarbStoreError) throws {
        let data = try PropertyListEncoder().encode(TestContainer(carbStoreError: original))
        let decoded = try PropertyListDecoder().decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.carbStoreError, original)
    }

    private struct TestContainer: Codable, Equatable {
        let carbStoreError: CarbStore.CarbStoreError
    }
}

extension CarbStore.CarbStoreError: Equatable {
    public static func == (lhs: CarbStore.CarbStoreError, rhs: CarbStore.CarbStoreError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured):
            return true
        case (.healthStoreError(let lhsError), .healthStoreError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.unauthorized, .unauthorized),
             (.noData, .noData):
            return true
        default:
            return false
        }
    }
}
