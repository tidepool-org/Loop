//
//  SetBolusErrorTests.swift
//  LoopTests
//
//  Created by Darin Krauss on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit

class SetBolusErrorCodableTests: XCTestCase {
    func testCodableCertain() throws {
        try assertSetBolusErrorCodable(.certain(TestLocalizedError()))
    }
    
    func testCodableUncertain() throws {
        try assertSetBolusErrorCodable(.uncertain(TestLocalizedError()))
    }
    
    func assertSetBolusErrorCodable(_ original: SetBolusError) throws {
        let data = try PropertyListEncoder().encode(TestContainer(setBolusError: original))
        let decoded = try PropertyListDecoder().decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.setBolusError, original)
    }
    
    private struct TestContainer: Codable, Equatable {
        let setBolusError: SetBolusError
    }
}

extension SetBolusError: Equatable {
    public static func == (lhs: SetBolusError, rhs: SetBolusError) -> Bool {
        switch (lhs, rhs) {
        case (.certain(let lhsLocalizedError), .certain(let rhsLocalizedError)),
             (.uncertain(let lhsLocalizedError), .uncertain(let rhsLocalizedError)):
            return lhsLocalizedError.errorDescription == rhsLocalizedError.errorDescription &&
                lhsLocalizedError.failureReason == rhsLocalizedError.failureReason &&
                lhsLocalizedError.helpAnchor == rhsLocalizedError.helpAnchor &&
                lhsLocalizedError.recoverySuggestion == rhsLocalizedError.recoverySuggestion
        default:
            return false
        }
    }
}

struct TestLocalizedError: LocalizedError {
    public let errorDescription: String?
    public let failureReason: String?
    public let helpAnchor: String?
    public let recoverySuggestion: String?
    
    init() {
        self.errorDescription = UUID().uuidString
        self.failureReason = UUID().uuidString
        self.helpAnchor = UUID().uuidString
        self.recoverySuggestion = UUID().uuidString
    }
}
