//
//  PumpManagerErrorTests.swift
//  LoopTests
//
//  Created by Darin Krauss on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit

class PumpManagerErrorCodableTests: XCTestCase {
    func testCodableConfigurationWithLocalizedError() throws {
        try assertPumpManagerErrorCodable(.configuration(TestLocalizedError()))
    }
    
    func testCodableConfigurationWithoutLocalizedError() throws {
        try assertPumpManagerErrorCodable(.configuration(nil))
    }
    
    func testCodableConnectionWithLocalizedError() throws {
        try assertPumpManagerErrorCodable(.connection(TestLocalizedError()))
    }
    
    func testCodableConnectionWithoutLocalizedError() throws {
        try assertPumpManagerErrorCodable(.connection(nil))
    }
    
    func testCodableCommunicationWithLocalizedError() throws {
        try assertPumpManagerErrorCodable(.communication(TestLocalizedError()))
    }
    
    func testCodableCommunicationWithoutLocalizedError() throws {
        try assertPumpManagerErrorCodable(.communication(nil))
    }
    
    func testCodableDeviceStateWithLocalizedError() throws {
        try assertPumpManagerErrorCodable(.deviceState(TestLocalizedError()))
    }
    
    func testCodableDeviceStateWithoutLocalizedError() throws {
        try assertPumpManagerErrorCodable(.deviceState(nil))
    }
    
    func assertPumpManagerErrorCodable(_ original: PumpManagerError) throws {
        let data = try PropertyListEncoder().encode(TestContainer(pumpManagerError: original))
        let decoded = try PropertyListDecoder().decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.pumpManagerError, original)
    }
    
    private struct TestContainer: Codable, Equatable {
        let pumpManagerError: PumpManagerError
    }
}

extension PumpManagerError: Equatable {
    public static func == (lhs: PumpManagerError, rhs: PumpManagerError) -> Bool {
        switch (lhs, rhs) {
        case (.configuration(let lhsLocalizedError), .configuration(let rhsLocalizedError)),
             (.connection(let lhsLocalizedError), .connection(let rhsLocalizedError)),
             (.communication(let lhsLocalizedError), .communication(let rhsLocalizedError)),
             (.deviceState(let lhsLocalizedError), .deviceState(let rhsLocalizedError)):
            return lhsLocalizedError?.localizedDescription == rhsLocalizedError?.localizedDescription &&
                lhsLocalizedError?.errorDescription == rhsLocalizedError?.errorDescription &&
                lhsLocalizedError?.failureReason == rhsLocalizedError?.failureReason &&
                lhsLocalizedError?.helpAnchor == rhsLocalizedError?.helpAnchor &&
                lhsLocalizedError?.recoverySuggestion == rhsLocalizedError?.recoverySuggestion
        default:
            return false
        }
    }
}
