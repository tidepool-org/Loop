//
//  StoredAlert+CoreDataClass.swift
//  Loop
//
//  Created by Rick Pasetto on 5/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData
import LoopKit

public class StoredAlert: NSManagedObject {
    
    var interruptionLevel: Alert.InterruptionLevel {
        get {
            willAccessValue(forKey: "interruptionLevel")
            defer { didAccessValue(forKey: "interruptionLevel") }
            return Alert.InterruptionLevel(storedValue: primitiveInterruptionLevel)!
        }
        set {
            willChangeValue(forKey: "interruptionLevel")
            defer { didChangeValue(forKey: "interruptionLevel") }
            primitiveInterruptionLevel = newValue.storedValue
        }
    }
      
    var triggerDateMatching: DateComponents? {
        get {
            willAccessValue(forKey: "triggerDateMatching")
            defer { didAccessValue(forKey: "triggerDateMatching") }
            return primitiveTriggerDateMatching.map { try! Self.decoder.decode(DateComponents.self, from: $0) }
        }
        set {
            willChangeValue(forKey: "triggerDateMatching")
            defer { didChangeValue(forKey: "triggerDateMatching") }
            primitiveTriggerDateMatching = newValue.map { try! Self.encoder.encode($0) }
        }
    }
    
    var hasUpdatedModificationCounter: Bool { changedValues().keys.contains("modificationCounter") }

    func updateModificationCounter() { setPrimitiveValue(managedObjectContext!.modificationCounter!, forKey: "modificationCounter") }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        updateModificationCounter()
    }

    public override func willSave() {
        if isUpdated && !hasUpdatedModificationCounter {
            updateModificationCounter()
        }
        super.willSave()
    }
}

extension StoredAlert: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(acknowledgedDate, forKey: .acknowledgedDate)
        try container.encode(alertIdentifier, forKey: .alertIdentifier)
        try container.encodeIfPresent(backgroundContent, forKey: .backgroundContent)
        try container.encodeIfPresent(foregroundContent, forKey: .foregroundContent)
        try container.encode(interruptionLevel, forKey: .interruptionLevel)
        try container.encode(issuedDate, forKey: .issuedDate)
        try container.encode(managerIdentifier, forKey: .managerIdentifier)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(modificationCounter, forKey: .modificationCounter)
        try container.encodeIfPresent(retractedDate, forKey: .retractedDate)
        try container.encodeIfPresent(sound, forKey: .sound)
        try container.encodeIfPresent(syncIdentifier, forKey: .syncIdentifier)
        try container.encodeIfPresent(triggerInterval?.doubleValue, forKey: .triggerInterval)
        try container.encodeIfPresent(triggerDateMatching, forKey: .triggerDateMatching)
        try container.encode(triggerType, forKey: .triggerType)
    }

    private enum CodingKeys: String, CodingKey {
        case acknowledgedDate
        case alertIdentifier
        case backgroundContent
        case foregroundContent
        case interruptionLevel
        case issuedDate
        case managerIdentifier
        case metadata
        case modificationCounter
        case retractedDate
        case sound
        case syncIdentifier
        case triggerInterval
        case triggerDateMatching
        case triggerType
    }
}
