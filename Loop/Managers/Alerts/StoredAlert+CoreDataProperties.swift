//
//  StoredAlert+CoreDataProperties.swift
//  Loop
//
//  Created by Rick Pasetto on 5/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData


extension StoredAlert {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StoredAlert> {
        return NSFetchRequest<StoredAlert>(entityName: "StoredAlert")
    }

    @NSManaged public var acknowledgedDate: Date?
    @NSManaged public var alertIdentifier: String
    @NSManaged public var backgroundContent: String?
    @NSManaged public var foregroundContent: String?
    @NSManaged var primitiveInterruptionLevel: NSNumber
    @NSManaged public var issuedDate: Date
    @NSManaged public var managerIdentifier: String
    @NSManaged public var metadata: String?
    @NSManaged public var modificationCounter: Int64
    @NSManaged public var retractedDate: Date?
    @NSManaged public var sound: String?
    @NSManaged public var syncIdentifier: UUID?
    @NSManaged public var triggerInterval: NSNumber?
    @NSManaged var primitiveTriggerDateMatching: Data?
    @NSManaged public var triggerType: Int16
    
}
