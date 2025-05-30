//
//  DoseEnactor.swift
//  Loop
//
//  Created by Pete Schwamb on 7/30/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import LoopAlgorithm

class DoseEnactor {
    
    fileprivate let dosingQueue: DispatchQueue = DispatchQueue(label: "com.loopkit.DeviceManagerDosingQueue", qos: .utility)
    
    private let log = DiagnosticLog(category: "DoseEnactor")

    func enact(decisionId: UUID?, recommendation: AutomaticDoseRecommendation, with pumpManager: PumpManager) async throws {

        self.log.default("Enacting recommended basal change")
        try await pumpManager.enactTempBasal(decisionId: decisionId, unitsPerHour: recommendation.basalAdjustment.unitsPerHour, for: recommendation.basalAdjustment.duration)

        if let bolusUnits = recommendation.bolusUnits, bolusUnits > 0 {
            self.log.default("Enacting recommended bolus dose")
            try await pumpManager.enactBolus(decisionId: decisionId, units: bolusUnits, activationType: .automatic)
        }
    }
}

