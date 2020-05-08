//
//  DosingDecisionStore.swift
//  Loop
//
//  Created by Darin Krauss on 5/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

extension DosingDecisionStore {
    public func storeDosingDecision(_ dosingDecision: StoredDosingDecision, completion: @escaping () -> Void) {
        if let data = encodeDosingDecision(dosingDecision) {
            storeDosingDecisionData(StoredDosingDecisionData(date: dosingDecision.date, data: data), completion: completion)
        }
    }

    private static var encoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }()

    private func encodeDosingDecision(_ dosingDecision: StoredDosingDecision) -> Data? {
        do {
            return try DosingDecisionStore.encoder.encode(dosingDecision)
        } catch let error {
            log.error("Error encoding StoredDosingDecision: %@", String(describing: error))
            return nil
        }
    }

    private static var decoder: PropertyListDecoder = PropertyListDecoder()

    private func decodeDosingDecision(fromData data: Data) -> StoredDosingDecision? {
        do {
            return try DosingDecisionStore.decoder.decode(StoredDosingDecision.self, from: data)
        } catch let error {
            log.error("Error decoding StoredDosingDecision: %@", String(describing: error))
            return nil
        }
    }
}

extension DosingDecisionStore {
    public enum DosingDecisionQueryResult {
        case success(QueryAnchor, [StoredDosingDecision])
        case failure(Error)
    }

    public func executeDosingDecisionQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (DosingDecisionQueryResult) -> Void) {
        executeDosingDecisionDataQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let anchor, let dosingDecisionData):
                completion(.success(anchor, dosingDecisionData.compactMap { self.decodeDosingDecision(fromData: $0.data) }))
            }
        }
    }
}
