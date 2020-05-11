//
//  PersistentDeviceAlertLog.swift
//  Loop
//
//  Created by Rick Pasetto on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData
import LoopKit

public class PersistentDeviceAlertLog {
    
    private let storageFile: URL
    
    private let managedObjectContext: NSManagedObjectContext

    private let persistentContainer: NSPersistentContainer
    
    private let maxEntryAge: TimeInterval
    
    private var earliestLogEntryDate: Date {
        return Date(timeIntervalSinceNow: -maxEntryAge)
    }
    
    private let log = DiagnosticLog(category: "PersistentDeviceAlertLog")
    
    public init(storageFile: URL, maxEntryAge: TimeInterval = TimeInterval(7 * 24 * 60 * 60)) {
        self.storageFile = storageFile
        self.maxEntryAge = maxEntryAge
        print("storageFile: \(storageFile)")
        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        managedObjectContext.automaticallyMergesChangesFromParent = true

        let storeDescription = NSPersistentStoreDescription(url: storageFile)
        persistentContainer = NSPersistentContainer(name: "DeviceAlertLog")
        persistentContainer.persistentStoreDescriptions = [storeDescription]
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        managedObjectContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
    }
    
    public func record(alert: DeviceAlert, completion: ((Error?) -> Void)? = nil) {
        managedObjectContext.perform {
            _ = DeviceAlertLogEntry(from: alert, context: self.managedObjectContext, timestamp: Date())
            do {
                try self.managedObjectContext.save()
                self.log.default("Recorded alert: %{public}@ ", alert.identifier.value)
                completion?(nil)
            } catch {
                self.log.error("Could not store alert: %{public}@", String(describing: error))
                completion?(error)
            }
        }
    }
    
    public func recordAcknowledgement(of identifier: DeviceAlert.Identifier, completion: ((Error?) -> Void)? = nil) {
        managedObjectContext.perform {
            _ = DeviceAlertLogEntry(from: identifier, recordType: .acknowledged, context: self.managedObjectContext, timestamp: Date())
            do {
                try self.managedObjectContext.save()
                self.log.default("Recorded alert acknowledgement: %{public}@ ", identifier.value)
                completion?(nil)
            } catch {
                self.log.error("Could not store alert: %{public}@", String(describing: error))
                completion?(error)
            }
        }
    }
    
    public func recordRetraction(of identifier: DeviceAlert.Identifier, completion: ((Error?) -> Void)? = nil) {
        managedObjectContext.perform {
            _ = DeviceAlertLogEntry(from: identifier, recordType: .retracted, context: self.managedObjectContext, timestamp: Date())
            do {
                try self.managedObjectContext.save()
                self.log.default("Recorded alert retraction: %{public}@ ", identifier.value)
                completion?(nil)
            } catch {
                self.log.error("Could not store alert: %{public}@", String(describing: error))
                completion?(error)
            }
        }
    }

    // Should only be called from managed object context queue
    private func purgeExpiredLogEntries() {
        let predicate = NSPredicate(format: "timestamp < %@", earliestLogEntryDate as NSDate)

        do {
            let fetchRequest: NSFetchRequest<DeviceAlertLogEntry> = DeviceAlertLogEntry.fetchRequest()
            fetchRequest.predicate = predicate
            let count = try managedObjectContext.deleteObjects(matching: fetchRequest)
            log.info("Deleted %d DeviceAlertLogEntries", count)
        } catch let error {
            log.error("Could not purge expired alert log entry %{public}@", String(describing: error))
        }
    }
}

extension NSManagedObjectContext {

    fileprivate func deleteObjects<T>(matching fetchRequest: NSFetchRequest<T>) throws -> Int where T: NSManagedObject {
        let objects = try fetch(fetchRequest)

        for object in objects {
            delete(object)
        }

        if hasChanges {
            try save()
        }

        return objects.count
    }
}
