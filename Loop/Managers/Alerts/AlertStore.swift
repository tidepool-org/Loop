//
//  PersistentDeviceAlertLog.swift
//  Loop
//
//  Created by Rick Pasetto on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData
import LoopKit

public class AlertStore {
    
    public enum AlertStoreError: Swift.Error {
        case notFound
    }
    
    private let storageFile: URL
    
    private let managedObjectContext: NSManagedObjectContext

    private let persistentContainer: NSPersistentContainer
        
    private let log = DiagnosticLog(category: "AlertStore")

    private let dataAccessQueue = DispatchQueue(label: "com.loop.AlertStore.dataAccessQueue", qos: .utility)
    
    public init(storageFile: URL) {
        self.storageFile = storageFile
        print("AlertStore: \(storageFile)")
        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        managedObjectContext.automaticallyMergesChangesFromParent = true

        let storeDescription = NSPersistentStoreDescription(url: storageFile)
        persistentContainer = NSPersistentContainer(name: "AlertStore")
        persistentContainer.persistentStoreDescriptions = [storeDescription]
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        managedObjectContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
    }
}

// MARK: Alert Recording

extension AlertStore {
    
    public func recordIssued(alert: DeviceAlert, at timestamp: Date = Date(), completion: ((Swift.Error?) -> Void)? = nil) {
        dataAccessQueue.async {
            self.managedObjectContext.perform {
                _ = StoredAlert(from: alert, context: self.managedObjectContext, issuedTimestamp: timestamp)
                do {
                    try self.managedObjectContext.save()
                    self.log.default("Recorded alert: %{public}@", alert.identifier.value)
                    completion?(nil)
                } catch {
                    self.log.error("Could not store alert: %{public}@", String(describing: error))
                    completion?(error)
                }
            }
        }
    }
    
    private func lookupLatest(identifier: DeviceAlert.Identifier, completion: @escaping (Result<StoredAlert?, Swift.Error>) -> Void) {
        managedObjectContext.perform {
            let predicate = NSPredicate(format: "identifier = %@", identifier.value)
            do {
                let fetchRequest: NSFetchRequest<StoredAlert> = StoredAlert.fetchRequest()
                fetchRequest.predicate = predicate
                fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "modificationCounter", ascending: true) ]
                let result = try self.managedObjectContext.fetch(fetchRequest)
                completion(.success(result.last))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func recordUpdateOfLatest(of identifier: DeviceAlert.Identifier, at timestamp: Date = Date(),
                                      with block: @escaping (StoredAlert) -> Void,
                                      completion: ((Result<Void, Swift.Error>) -> Void)?) {
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
                                completion?(.success(Void()))
                            } catch {
                                self.log.error("Could not store alert: %{public}@", String(describing: error))
                                completion?(error)
                            }
                        } else {
                            completion?(AlertStoreError.notFound)
                        }
                    case .failure(let error):
                        completion?(error)
                    }
                }
            }
        }
    }
    
    public func recordAcknowledgement(of identifier: DeviceAlert.Identifier, at timestamp: Date = Date(),
                                      completion: ((Result<Void, Swift.Error>) -> Void)? = nil) {
        recordUpdateOfLatest(of: identifier, at: timestamp, with: { $0.acknowledgedTimestamp = timestamp }, completion: completion)
    }
    
    public func recordRetraction(of identifier: DeviceAlert.Identifier, at timestamp: Date = Date(),
                                 completion: ((Result<Void, Swift.Error>) -> Void)? = nil) {
        recordUpdateOfLatest(of: identifier, at: timestamp, with: { $0.retractedTimestamp = timestamp }, completion: completion)
    }
}

// MARK: Query Support

extension AlertStore {
    public struct QueryAnchor: RawRepresentable {
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

    
    func executeAlertQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (QueryResult) -> Void) {
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

}
