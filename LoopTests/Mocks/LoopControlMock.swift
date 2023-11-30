//
//  LoopControlMock.swift
//  LoopTests
//
//  Created by Pete Schwamb on 11/30/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
@testable import Loop


struct LoopControlMock: LoopControl {
    var lastLoopCompleted: Date?
    
    func cancelActiveTempBasal(for reason: Loop.CancelActiveTempBasalReason) async {
    }
    
    func loop() async {
    }
}
