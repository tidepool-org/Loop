//
//  StoredAlert.swift
//  Loop
//
//  Created by Rick Pasetto on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData
import LoopKit
import UIKit

extension StoredAlert {
    
    static var encoder = JSONEncoder()
    static var decoder = JSONDecoder()
          
    convenience init(from alert: Alert, context: NSManagedObjectContext, issuedDate: Date = Date(), syncIdentifier: UUID = UUID()) {
        do {
            /// This code, using the `init(entity:insertInto:)` instead of the `init(context:)` avoids warnings during unit testing that look like this:
            /// `CoreData: warning: Multiple NSEntityDescriptions claim the NSManagedObject subclass 'Loop.StoredAlert' so +entity is unable to disambiguate.`
            /// This mitigates that.  See https://stackoverflow.com/a/54126839 for more info.
            let name = String(describing: type(of: self))
            let entity = NSEntityDescription.entity(forEntityName: name, in: context)!
            self.init(entity: entity, insertInto: context)
            self.issuedDate = issuedDate
            self.alertIdentifier = alert.identifier.alertIdentifier
            self.managerIdentifier = alert.identifier.managerIdentifier
            self.triggerType = alert.trigger.storedType
            self.triggerInterval = alert.trigger.storedInterval
            self.triggerDateMatching = alert.trigger.storedDateMatching
            self.interruptionLevel = alert.interruptionLevel
            self.syncIdentifier = syncIdentifier
            // Encode as JSON strings
            let encoder = StoredAlert.encoder
            self.sound = try encoder.encodeToStringIfPresent(alert.sound)
            self.foregroundContent = try encoder.encodeToStringIfPresent(alert.foregroundContent)
            self.backgroundContent = try encoder.encodeToStringIfPresent(alert.backgroundContent)
            self.metadata = try encoder.encodeToStringIfPresent(alert.metadata)
        } catch {
            fatalError("Failed to encode: \(error)")
        }
    }

    public var trigger: Alert.Trigger {
        get {
            do {
                return try Alert.Trigger(storedType: triggerType, storedInterval: triggerInterval, storedDateMatching: triggerDateMatching)
            } catch {
                fatalError("\(error): \(triggerType) \(String(describing: triggerInterval))")
            }
        }
    }
    
    public var title: String? {
        return try? Alert.Content(contentString: foregroundContent ?? backgroundContent)?.title
    }
    
    public var identifier: Alert.Identifier {
        return Alert.Identifier(managerIdentifier: managerIdentifier, alertIdentifier: alertIdentifier)
    }
}

extension Alert {
    init(from storedAlert: StoredAlert, adjustedForStorageTime: Bool) throws {
        let fgContent = try Alert.Content(contentString: storedAlert.foregroundContent)
        let bgContent = try Alert.Content(contentString: storedAlert.backgroundContent)
        let sound = try Alert.Sound(soundString: storedAlert.sound)
        let metadata = try Alert.Metadata(metadataString: storedAlert.metadata)
        let trigger = try Alert.Trigger(storedType: storedAlert.triggerType,
                                        storedInterval: storedAlert.triggerInterval,
                                        storedDateMatching: storedAlert.triggerDateMatching,
                                        storageDate: adjustedForStorageTime ? storedAlert.issuedDate : nil)
        self.init(identifier: storedAlert.identifier,
                  foregroundContent: fgContent,
                  backgroundContent: bgContent,
                  trigger: trigger,
                  interruptionLevel: storedAlert.interruptionLevel,
                  sound: sound,
                  metadata: metadata)
    }
}

extension Alert.Content {
    init?(contentString: String?) throws {
        guard let contentString = contentString else {
            return nil
        }
        guard let contentData = contentString.data(using: .utf8) else {
            throw JSONEncoderError.stringEncodingError
        }
        self = try StoredAlert.decoder.decode(Alert.Content.self, from: contentData)
    }
}

extension Alert.Sound {
    init?(soundString: String?) throws {
        guard let soundString = soundString else {
            return nil
        }
        guard let soundData = soundString.data(using: .utf8) else {
            throw JSONEncoderError.stringEncodingError
        }
        self = try StoredAlert.decoder.decode(Alert.Sound.self, from: soundData)
    }
}

extension Alert.Metadata {
    init?(metadataString: String?) throws {
        guard let metadataString = metadataString else {
            return nil
        }
        guard let metadataData = metadataString.data(using: .utf8) else {
            throw JSONEncoderError.stringEncodingError
        }
        self = try StoredAlert.decoder.decode(Alert.Metadata.self, from: metadataData)
    }
}

extension Alert.Trigger {
    enum StorageError: Error {
        case invalidStoredInterval, invalidStoredType, invalidStoredDateMatching
    }
    
    var storedType: Int16 {
        switch self {
        case .immediate: return 0
        case .delayed: return 1
        case .repeating: return 2
        case .nextDate: return 3
        case .nextDateRepeating: return 4
        }
    }
    var storedInterval: NSNumber? {
        switch self {
        case .immediate, .nextDate, .nextDateRepeating: return nil
        case .delayed(let interval): return NSNumber(value: interval)
        case .repeating(let repeatInterval): return NSNumber(value: repeatInterval)
        }
    }
    
    var storedDateMatching: DateComponents? {
        switch self {
        case .immediate, .delayed, .repeating: return nil
        case .nextDate(let matching): return matching
        case .nextDateRepeating(let matching): return matching
        }
    }

    init(storedType: Int16, storedInterval: NSNumber?, storedDateMatching: DateComponents?, storageDate: Date? = nil, now: Date = Date()) throws {
        switch storedType {
        case 0: self = .immediate
        case 1:
            if let storedInterval = storedInterval {
                if let storageDate = storageDate, storageDate <= now {
                    let intervalLeft = storedInterval.doubleValue - now.timeIntervalSince(storageDate)
                    if intervalLeft <= 0 {
                        self = .immediate
                    } else {
                        self = .delayed(interval: intervalLeft)
                    }
                } else {
                    self = .delayed(interval: storedInterval.doubleValue)
                }
            } else {
                throw StorageError.invalidStoredInterval
            }
        case 2:
            // Strange case here: if it is a repeating trigger, we can't really play back exactly
            // at the right "remaining time" and then repeat at the original period.  So, I think
            // the best we can do is just use the original trigger
            if let storedInterval = storedInterval {
                self = .repeating(repeatInterval: storedInterval.doubleValue)
            } else {
                throw StorageError.invalidStoredInterval
            }
        case 3:
            if let storedDateMatching = storedDateMatching {
                if let storageDate = storageDate,
                   let nextDate = Calendar.current.nextDate(after: storageDate, matching: storedDateMatching, matchingPolicy: .nextTime),
                   // Interesting case here, and I'm not exactly sure what to do.
                   // If the "next matching date" after storage date is in the past, that means we've past the time when the alert should have shown
                    // So... make it .immediate?? (TODO: Or, maybe we should throw an error?  Not clear...)
                   now > nextDate
                {
                    self = .immediate
                } else {
                    self = .nextDate(matching: storedDateMatching)
                }
            } else {
                throw StorageError.invalidStoredDateMatching
            }
        case 4:
            // Fortunately for repeating "next date" alerts, there's no "expiration"
            if let storedDateMatching = storedDateMatching {
                self = .nextDateRepeating(matching: storedDateMatching)
            } else {
                throw StorageError.invalidStoredDateMatching
            }
        default:
            throw StorageError.invalidStoredType
        }
    }
}

extension Alert.InterruptionLevel {
    
    var storedValue: NSNumber {
        // Since this is arbitrary anyway, might as well make it match iOS's values
        switch self {
        case .active:
            if #available(iOS 15.0, *) {
                return NSNumber(value: UNNotificationInterruptionLevel.active.rawValue)
            } else {
                // https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/active
                return 1
            }
        case .timeSensitive:
            if #available(iOS 15.0, *) {
                return NSNumber(value: UNNotificationInterruptionLevel.timeSensitive.rawValue)
            } else {
                // https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive
                return 2
            }
        case .critical:
            if #available(iOS 15.0, *) {
                return NSNumber(value: UNNotificationInterruptionLevel.critical.rawValue)
            } else {
                // https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/critical
                return 3
            }
        }
    }
    
    init?(storedValue: NSNumber) {
        switch storedValue {
        case Self.active.storedValue: self = .active
        case Self.timeSensitive.storedValue: self = .timeSensitive
        case Self.critical.storedValue: self = .critical
        default:
            return nil
        }
    }
}



enum JSONEncoderError: Swift.Error {
    case stringEncodingError
}

extension JSONEncoder {
    func encodeToStringIfPresent<T>(_ encodable: T?) throws -> String? where T: Encodable {
        guard let encodable = encodable else { return nil }
        let data = try self.encode(encodable)
        guard let result = String(data: data, encoding: .utf8) else {
            throw JSONEncoderError.stringEncodingError
        }
        return result
    }
}

extension SyncAlertObject {
    init?(managedObject: StoredAlert) throws {
        guard let syncIdentifier = managedObject.syncIdentifier else {
            return nil
        }
        self.init(identifier: managedObject.identifier,
                  trigger: try Alert.Trigger(storedType: managedObject.triggerType,
                                             storedInterval: managedObject.triggerInterval,
                                             storedDateMatching: managedObject.triggerDateMatching),
                  interruptionLevel: managedObject.interruptionLevel,
                  foregroundContent: try Alert.Content(contentString: managedObject.foregroundContent),
                  backgroundContent: try Alert.Content(contentString: managedObject.backgroundContent),
                  sound: try Alert.Sound(soundString: managedObject.sound),
                  metadata: try Alert.Metadata(metadataString: managedObject.metadata),
                  issuedDate: managedObject.issuedDate,
                  acknowledgedDate: managedObject.acknowledgedDate,
                  retractedDate: managedObject.retractedDate,
                  syncIdentifier: syncIdentifier
        )
    }
}
