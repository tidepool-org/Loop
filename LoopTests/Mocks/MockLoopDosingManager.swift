//
//  MockLoopDosingManager.swift
//  LoopTests
//
//  Created by Pete Schwamb on 10/31/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import XCTest
import Foundation
@testable import Loop

class MockLoopDosingManager: LoopDosingManagerProtocol {
    var lastCancelActiveTempBasalReason: CancelActiveTempBasalReason?

    var cancelExpectation: XCTestExpectation?

    func receivedUnreliableCGMReading() async {
    }
    
    func cancelActiveTempBasal(for reason: CancelActiveTempBasalReason) async {
        lastCancelActiveTempBasalReason = reason
        cancelExpectation?.fulfill()
    }
    
    func loop() async {
    }
}
