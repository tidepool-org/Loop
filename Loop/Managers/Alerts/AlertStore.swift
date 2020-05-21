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
    
    // Available for tests only
    let managedObjectContext: NSManagedObjectContext

    private let persistentContainer: NSPersistentContainer
        
    private let log = DiagnosticLog(category: "AlertStore")

    private let dataAccessQueue = DispatchQueue(label: "com.loop.AlertStore.dataAccessQueue", qos: .utility)
    
    public init(storageFileURL: URL? = nil) {
        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        managedObjectContext.automaticallyMergesChangesFromParent = true

        let storeDescription = NSPersistentStoreDescription()
        if let storageFileURL = storageFileURL {
            storeDescription.url = storageFileURL
        } else {
            storeDescription.type = NSInMemoryStoreType
        }
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        persistentContainer = NSPersistentContainer(name: "AlertStore")
        persistentContainer.persistentStoreDescriptions = [storeDescription]
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        managedObjectContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
    }
}

// MARK: Alert Recording

extension AlertStore {
    
    public func recordIssued(alert: DeviceAlert, at date: Date = Date(), completion: ((Result<Void, Error>) -> Void)? = nil) {
        dataAccessQueue.async {
            self.managedObjectContext.perform {
                _ = StoredAlert(from: alert, context: self.managedObjectContext, issuedDate: date)
                do {
                    try self.managedObjectContext.save()
                    self.log.default("Recorded alert: %{public}@", alert.identifier.value)
                    completion?(.success)
                } catch {
                    self.log.error("Could not store alert: %{public}@, %{public}@", alert.identifier.value, String(describing: error))
                    completion?(.failure(error))
                }
            }
        }
    }
    
    public func recordAcknowledgement(of identifier: DeviceAlert.Identifier, at date: Date = Date(),
                                      completion: ((Result<Void, Error>) -> Void)? = nil) {
        recordUpdateOfLatest(of: identifier, with: { $0.acknowledgedDate = date }, completion: completion)
    }
    
    public func recordRetraction(of identifier: DeviceAlert.Identifier, at date: Date = Date(),
                                 completion: ((Result<Void, Error>) -> Void)? = nil) {
        recordUpdateOfLatest(of: identifier, with: { $0.retractedDate = date }, completion: completion)
    }
    
    private func recordUpdateOfLatest(of identifier: DeviceAlert.Identifier,
                                      with block: @escaping (StoredAlert) -> Void,
                                      completion: ((Result<Void, Error>) -> Void)?) {
        dataAccessQueue.async {
            self.managedObjectContext.perform {
                self.lookupLatest(identifier: identifier) {
                    switch $0 {
                    case .success(let object):
                        if let object = object {
                            block(object)
                            do {
                                try self.managedObjectContext.save()
                                self.log.default("Recorded alert: %{public}@", identifier.value)
                                completion?(.success)
                            } catch {
                                self.log.error("Could not store alert: %{public}@, %{public}@", identifier.value, String(describing: error))
                                completion?(.failure(error))
                            }
                        } else {
                            self.log.default("Alert not found for update: %{public}@", identifier.value)
                            completion?(.failure(AlertStoreError.notFound))
                        }
                    case .failure(let error):
                        completion?(.failure(error))
                    }
                }
            }
        }
    }
    
    private func lookupLatest(identifier: DeviceAlert.Identifier, completion: @escaping (Result<StoredAlert?, Error>) -> Void) {
        managedObjectContext.perform {
            let predicate = NSPredicate(format: "identifier = %@", identifier.value)
            do {
                let fetchRequest: NSFetchRequest<StoredAlert> = StoredAlert.fetchRequest()
                fetchRequest.predicate = predicate
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

// MARK: Query Support

extension AlertStore {

    public struct QueryAnchor: RawRepresentable, Equatable {
        public typealias RawValue = [String: Any]
        internal var modificationCounter: Int64
        public init() {
            self.modificationCounter = 0
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
    typealias QueryResult = Result<(QueryAnchor, [StoredAlert]), Error>

    func executeAlertQuery(fromQueryAnchor queryAnchor: QueryAnchor? = nil, limit: Int, completion: @escaping (QueryResult) -> Void) {
        dataAccessQueue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryResult = [StoredAlert]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success((queryAnchor, queryResult)))
                return
            }

            self.managedObjectContext.performAndWait {
                let storedRequest: NSFetchRequest<StoredAlert> = StoredAlert.fetchRequest()

                storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
                storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                storedRequest.fetchLimit = limit

                do {
                    let stored = try self.managedObjectContext.fetch(storedRequest)
                    if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                        queryAnchor.modificationCounter = modificationCounter
                    }
                    queryResult.append(contentsOf: stored)
                } catch let error {
                    queryError = error
                    return
                }
            }

            if let queryError = queryError {
                completion(.failure(queryError))
                return
            }

            completion(.success((queryAnchor, queryResult)))
        }
    }

    
    // At the moment, this is only used for unit testing
    internal func fetch(identifier: DeviceAlert.Identifier, completion: @escaping (Result<[StoredAlert], Error>) -> Void) {
        dataAccessQueue.async {
            self.managedObjectContext.performAndWait {
                let storedRequest: NSFetchRequest<StoredAlert> = StoredAlert.fetchRequest()
                storedRequest.predicate = NSPredicate(format: "identifier == %@", identifier.value)
                do {
                    let stored = try self.managedObjectContext.fetch(storedRequest)
                    completion(.success(stored))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
}

extension Result where Success == Void {
    static var success: Result {
        return Result.success(Void())
    }
}
