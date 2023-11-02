//
//  CarbStoreProtocol.swift
//  Loop
//
//  Created by Anna Quinlan on 8/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import HealthKit

protocol CarbStoreProtocol: AnyObject {
    
    var preferredUnit: HKUnit! { get }
    
    var delegate: CarbStoreDelegate? { get set }
    
    // MARK: Settings
    var maximumAbsorptionTimeInterval: TimeInterval { get }
    
    var delta: TimeInterval { get }
    
    var defaultAbsorptionTimes: CarbStore.DefaultAbsorptionTimes { get }
    
    // MARK: Data Management
    func replaceCarbEntry(_ oldEntry: StoredCarbEntry, withEntry newEntry: NewCarbEntry, completion: @escaping (_ result: CarbStoreResult<StoredCarbEntry>) -> Void)
    
    func addCarbEntry(_ entry: NewCarbEntry, completion: @escaping (_ result: CarbStoreResult<StoredCarbEntry>) -> Void)
    
    func generateDiagnosticReport(_ completion: @escaping (_ report: String) -> Void)
    
    // MARK: COB & Effect Generation
    func getTotalCarbs(since start: Date, completion: @escaping (_ result: CarbStoreResult<CarbValue>) -> Void)
    
    func deleteCarbEntry(_ entry: StoredCarbEntry, completion: @escaping (_ result: CarbStoreResult<Bool>) -> Void)
}

extension CarbStore: CarbStoreProtocol { }
