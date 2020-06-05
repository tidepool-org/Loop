//
//  CarbStore+SimulatedCoreData.swift
//  Loop
//
//  Created by Darin Krauss on 6/4/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

// MARK: - Simulated Core Data

extension CarbStore {
    private var historicalEndDate: Date { Date(timeIntervalSinceNow: -.hours(24)) }

    private var simulatedCachedPerDay: Int { 8 }
    private var simulatedDeletedPerDay: Int { 3 }

    public func generateSimulatedHistoricalCarbObjects(completion: @escaping (Error?) -> Void) {
        generateSimulatedHistoricalStoredCarbObjects() { error in
            guard error == nil else {
                completion(error)
                return
            }
            self.generateSimulatedHistoricalDeletedCarbObjects(completion: completion)
        }
    }

    private func generateSimulatedHistoricalStoredCarbObjects(completion: @escaping (Error?) -> Void) {
        var startDate = Calendar.current.startOfDay(for: earliestCacheDate)
        let endDate = Calendar.current.startOfDay(for: historicalEndDate)
        var entries = [StoredCarbEntry]()

        while startDate < endDate {
            for index in 0..<simulatedCachedPerDay {
                entries.append(StoredCarbEntry.simulated(startDate: startDate.addingTimeInterval(.hours(24) * Double(index) / Double(simulatedCachedPerDay)),
                                                         grams: Double(20 + 10 * (index % 3)),
                                                         absorptionTime: .hours(Double(2 + index % 3))))
            }
            startDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        }

        addStoredCarbEntries(entries: entries, completion: completion)
    }

    private func generateSimulatedHistoricalDeletedCarbObjects(completion: @escaping (Error?) -> Void) {
        var startDate = Calendar.current.startOfDay(for: earliestCacheDate)
        let endDate = Calendar.current.startOfDay(for: historicalEndDate)
        var entries = [DeletedCarbEntry]()

        while startDate < endDate {
            for index in 0..<simulatedDeletedPerDay {
                entries.append(DeletedCarbEntry.simulated(startDate: startDate.addingTimeInterval(.hours(24) * Double(index) / Double(simulatedDeletedPerDay))))
            }
            startDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        }

        addDeletedCarbEntries(entries: entries, completion: completion)
    }

    public func purgeHistoricalCarbObjects(completion: @escaping (Error?) -> Void) {
        purgeCachedCarbEntries(before: historicalEndDate, completion: completion)
    }
}

fileprivate extension StoredCarbEntry {
    static func simulated(startDate: Date, grams: Double, absorptionTime: TimeInterval) -> StoredCarbEntry {
        return StoredCarbEntry(sampleUUID: UUID(),
                               syncIdentifier: UUID().uuidString,
                               syncVersion: 1,
                               startDate: startDate,
                               unitString: HKUnit.gram().unitString,
                               value: grams,
                               foodType: "Simulated",
                               absorptionTime: absorptionTime,
                               createdByCurrentApp: true,
                               externalID: UUID().uuidString,
                               isUploaded: false)
    }
}

fileprivate extension DeletedCarbEntry {
    static func simulated(startDate: Date) -> DeletedCarbEntry {
        return DeletedCarbEntry(externalID: UUID().uuidString,
                                isUploaded: false,
                                startDate: startDate,
                                uuid: UUID(),
                                syncIdentifier: UUID().uuidString,
                                syncVersion: 1)
    }
}
