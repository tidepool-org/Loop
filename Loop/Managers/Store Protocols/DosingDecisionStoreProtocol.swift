//
//  DosingDecisionStoreProtocol.swift
//  Loop
//
//  Created by Anna Quinlan on 8/19/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

protocol DosingDecisionStoreProtocol: CriticalEventLog {
    var delegate: DosingDecisionStoreDelegate? { get set }

    func storeDosingDecision(_ dosingDecision: StoredDosingDecision) async

    func executeDosingDecisionQuery(fromQueryAnchor queryAnchor: DosingDecisionStore.QueryAnchor?, limit: Int, completion: @escaping (DosingDecisionStore.DosingDecisionQueryResult) -> Void)
    
    func findDosingDecisionsByDate(_ date: Date) async throws -> [StoredDosingDecision]
}

extension DosingDecisionStore: DosingDecisionStoreProtocol { }
