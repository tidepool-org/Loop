//
//  AlertStore.swift
//  Loop
//
//  Created by Rick Pasetto on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData
import LoopKit

public class AlertStore {

    public enum AlertStoreError: Error {
        case notFound
    }

    private enum PostUpdateAction {
        case save, delete
    }
    private typealias ManagedObjectUpdateBlock = (StoredAlert) -> PostUpdateAction
    
    // Available for tests only
    let managedObjectContext: NSManagedObjectContext

    private let persistentContainer: NSPersistentContainer

    private let expireAfter: TimeInterval

    private let log = DiagnosticLog(category: "AlertStore")

    public init(storageDirectoryURL: URL? = nil, expireAfter: TimeInterval = 24 /* hours */ * 60 /* minutes */ * 60 /* seconds */) {
        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        managedObjectContext.automaticallyMergesChangesFromParent = true

        let storeDescription = NSPersistentStoreDescription()
        if let storageDirectoryURL = storageDirectoryURL {
            let storageFileURL = storageDirectoryURL
                .appendingPathComponent("AlertStore")
                .appendingPathComponent("AlertStore.sqlite")
            storeDescription.url = storageFileURL
        } else {
            storeDescription.type = NSInMemoryStoreType
        }
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        persistentContainer = NSPersistentContainer(name: "AlertStore")
        persistentContainer.persistentStoreDescriptions = [storeDescription]

        let group = DispatchGroup()
        group.enter()
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
            group.leave()
        }
        group.wait()

        managedObjectContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator

        self.expireAfter = expireAfter
    }

    public func recordIssued(alert: Alert, at date: Date = Date(), completion: ((Result<Void, Error>) -> Void)? = nil) {
        self.managedObjectContext.perform {
            _ = StoredAlert(from: alert, context: self.managedObjectContext, issuedDate: date)
            do {
                try self.managedObjectContext.save()
                self.log.default("Recorded alert: %{public}@", alert.identifier.value)
                self.purgeExpired()
                completion?(.success)
            } catch {
                self.log.error("Could not store alert: %{public}@, %{public}@", alert.identifier.value, String(describing: error))
                completion?(.failure(error))
            }
        }
    }
    
    public func recordAcknowledgement(of identifier: Alert.Identifier, at date: Date = Date(),
                                      completion: ((Result<Void, Error>) -> Void)? = nil) {
        recordUpdateOfLatest(of: identifier,
                             addingPredicate: NSPredicate(format: "acknowledgedDate == nil"),
                             with: { $0.acknowledgedDate = date; return .save },
                             completion: completion)
    }
    
    public func recordRetraction(of identifier: Alert.Identifier, at date: Date = Date(),
                                 completion: ((Result<Void, Error>) -> Void)? = nil) {
        recordUpdateOfLatest(of: identifier,
                             addingPredicate: NSPredicate(format: "retractedDate == nil"),
                             with: {
                                // if the alert was retracted before it was ever shown, delete it. Note: this only
                                // applies to .delayed alerts!
                                if case .delayed(let interval) = $0.trigger, $0.issuedDate + interval >= date {
                                    return .delete
                                } else {
                                    $0.retractedDate = date
                                    return .save
                                }
                             },
                             completion: completion)
    }
    
    public func lookupAllUnacknowledged(completion: @escaping (Result<[StoredAlert], Error>) -> Void) {
        managedObjectContext.perform {
            do {
                let fetchRequest: NSFetchRequest<StoredAlert> = StoredAlert.fetchRequest()
                fetchRequest.predicate =  NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "acknowledgedDate == nil"),
                    NSPredicate(format: "retractedDate == nil")
                ])
                fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "modificationCounter", ascending: true) ]
                let result = try self.managedObjectContext.fetch(fetchRequest)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }

}

// MARK: Private functions

extension AlertStore {

    private func recordUpdateOfLatest(of identifier: Alert.Identifier,
                                      addingPredicate predicate: NSPredicate,
                                      with block: @escaping ManagedObjectUpdateBlock,
                                      completion: ((Result<Void, Error>) -> Void)?) {
        self.managedObjectContext.perform {
            self.lookupLatest(identifier: identifier, predicate: predicate) {
                switch $0 {
                case .success(let object):
                    if let object = object {
                        let shouldDelete = block(object) == .delete
                        do {
                            if shouldDelete {
                                self.managedObjectContext.delete(object)
                            }
                            try self.managedObjectContext.save()
                            self.log.default("%{public}@ alert: %{public}@", shouldDelete ? "Deleted" : "Recorded", identifier.value)
                            self.purgeExpired()
                            completion?(.success)
                        } catch {
                            self.log.error("Could not store alert: %{public}@, %{public}@", identifier.value, String(describing: error))
                            completion?(.failure(error))
                        }
                    } else {
                        self.log.error("Alert not found for update: %{public}@", identifier.value)
                        completion?(.failure(AlertStoreError.notFound))
                    }
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
        }
    }

    private func lookupLatest(identifier: Alert.Identifier, predicate: NSPredicate, completion: @escaping (Result<StoredAlert?, Error>) -> Void) {
        managedObjectContext.perform {
            do {
                let fetchRequest: NSFetchRequest<StoredAlert> = StoredAlert.fetchRequest()
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    identifier.equalsPredicate,
                    predicate
                ])
                fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "modificationCounter", ascending: false) ]
                fetchRequest.fetchLimit = 1
                let result = try self.managedObjectContext.fetch(fetchRequest)
                completion(.success(result.last))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: Alert Purging

extension AlertStore {
    var expireDate: Date {
        return Date(timeIntervalSinceNow: -expireAfter)
    }

    private func purgeExpired() {
        purge(before: expireDate)
    }

    func purge(before date: Date, completion: ((Error?) -> Void)? = nil) {
        do {
            let fetchRequest: NSFetchRequest<StoredAlert> = StoredAlert.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "issuedDate < %@", date as NSDate)
            let count = try self.managedObjectContext.deleteObjects(matching: fetchRequest)
            self.log.info("Purged %d StoredAlerts", count)
            completion?(nil)
        } catch let error {
            self.log.error("Unable to purge StoredAlerts: %{public}@", String(describing: error))
            completion?(error)
        }
    }
}

// MARK: Query Support

public protocol QueryFilter: Equatable {
    var predicate: NSPredicate? { get }
}

extension AlertStore {

    public struct QueryAnchor<Filter: QueryFilter>: RawRepresentable, Equatable {
        public typealias RawValue = [String: Any]
        internal var modificationCounter: Int64
        internal var filter: Filter?
        public init() {
            self.modificationCounter = 0
        }
        init(modificationCounter: Int64? = nil, filter: Filter?) {
            self.modificationCounter = modificationCounter ?? 0
            self.filter = filter
        }
        public init?(rawValue: RawValue) {
            guard let modificationCounter = rawValue["modificationCounter"] as? Int64 else {
                return nil
            }
            self.modificationCounter = modificationCounter
        }
        public var rawValue: RawValue {
            var rawValue: RawValue = [:]
            rawValue["modificationCounter"] = modificationCounter
            return rawValue
        }
    }
    typealias QueryResult<Filter: QueryFilter> = Result<(QueryAnchor<Filter>, [StoredAlert]), Error>

    struct NoFilter: QueryFilter {
        let predicate: NSPredicate?
    }
    struct SinceDateFilter: QueryFilter {
        let date: Date
        let now: Date
        let excludingFutureAlerts: Bool
        var predicate: NSPredicate? {
            let datePredicate = NSPredicate(format: "issuedDate >= %@", date as NSDate)
            // if case .delayed(let interval) = $0.trigger, $0.issuedDate + interval >= date {
            let futurePredicate = NSPredicate(format: "triggerInterval == nil OR (triggerType == 1 AND CAST(issuedDate, 'NSNumber') + triggerInterval < CAST(%@, 'NSNumber'))", now as NSDate)
            return excludingFutureAlerts ?
                NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, futurePredicate])
                : datePredicate
        }
    }

    func executeQuery(since date: Date, excludingFutureAlerts: Bool = true, now: Date = Date(), limit: Int, completion: @escaping (QueryResult<SinceDateFilter>) -> Void) {
        executeAlertQuery(from: QueryAnchor(filter: SinceDateFilter(date: date, now: now, excludingFutureAlerts: excludingFutureAlerts)), limit: limit, completion: completion)
    }

    func continueQuery<Filter: QueryFilter>(from anchor: QueryAnchor<Filter>, limit: Int, completion: @escaping (QueryResult<Filter>) -> Void) {
        executeAlertQuery(from: anchor, limit: limit, completion: completion)
    }

    private func executeAlertQuery<Filter: QueryFilter>(from anchor: QueryAnchor<Filter>, limit: Int, completion: @escaping (QueryResult<Filter>) -> Void) {
        self.managedObjectContext.perform {
            guard limit > 0 else {
                completion(.success((anchor, [])))
                return
            }
            let storedRequest: NSFetchRequest<StoredAlert> = StoredAlert.fetchRequest()
            let anchorPredicate = NSPredicate(format: "modificationCounter > %d", anchor.modificationCounter)
            if let filterPredicate = anchor.filter?.predicate {
                storedRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    anchorPredicate,
                    filterPredicate
                ])
            } else {
                storedRequest.predicate = anchorPredicate
            }
            storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
            storedRequest.fetchLimit = limit

            do {
                let stored = try self.managedObjectContext.fetch(storedRequest)
                let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter
                let newAnchor = QueryAnchor<Filter>(modificationCounter: modificationCounter, filter: anchor.filter)
                completion(.success((newAnchor, stored)))
            } catch let error {
                completion(.failure(error))
            }
        }
    }

    // At the moment, this is only used for unit testing
    internal func fetch(identifier: Alert.Identifier? = nil, completion: @escaping (Result<[StoredAlert], Error>) -> Void) {
        self.managedObjectContext.perform {
            let storedRequest: NSFetchRequest<StoredAlert> = StoredAlert.fetchRequest()
            storedRequest.predicate = identifier?.equalsPredicate
            storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
            do {
                let stored = try self.managedObjectContext.fetch(storedRequest)
                completion(.success(stored))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

extension Alert.Identifier {
    var equalsPredicate: NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "managerIdentifier == %@", managerIdentifier),
            NSPredicate(format: "alertIdentifier == %@", alertIdentifier)
        ])
    }
}

extension Result where Success == Void {
    static var success: Result {
        return Result.success(Void())
    }
}

// MARK: - Core Data (Bulk) - TEST ONLY

extension AlertStore {
    struct DatedAlert {
        let date: Date
        let alert: Alert
    }

    func addAlerts(alerts: [DatedAlert]) -> Error? {
        guard !alerts.isEmpty else {
            return nil
        }

        var error: Error?

        self.managedObjectContext.performAndWait {
            for alert in alerts {
                let storedAlert = StoredAlert(from: alert.alert, context: self.managedObjectContext, issuedDate: alert.date)
                storedAlert.acknowledgedDate = alert.date
            }

            do {
                try self.managedObjectContext.save()
            } catch let saveError {
                error = saveError
            }
        }

        guard error == nil else {
            return error
        }

        self.log.info("Added %d StoredAlerts", alerts.count)
        return nil
    }
}
