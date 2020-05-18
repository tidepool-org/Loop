//
//  StoredAlertObject+CoreDataProperties.swift
//  Loop
//
//  Created by Rick Pasetto on 5/18/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData

extension StoredAlertObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StoredAlertObject> {
        return NSFetchRequest<StoredAlertObject>(entityName: "StoredAlertObject")
    }

    @NSManaged public var issuedTimestamp: Date
    @NSManaged public var acknowledgedTimestamp: Date?
    @NSManaged public var retractedTimestamp: Date?
    @NSManaged public var backgroundContent: String?
    @NSManaged public var foregroundContent: String?
    @NSManaged public var identifier: String
    @NSManaged public var isCritical: Bool
    @NSManaged public var modificationCounter: Int64
    @NSManaged public var sound: String?
    @NSManaged public var trigger: String?

}
