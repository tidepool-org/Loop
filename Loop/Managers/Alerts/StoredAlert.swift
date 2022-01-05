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
          
    convenience init(from alert: Alert, context: NSManagedObjectContext, issuedDate: Date = Date()) {
        do {
            let name = String(describing: type(of: self))
            let entity = NSEntityDescription.entity(forEntityName: name, in: context)!
            self.init(entity: entity, insertInto: context)
            self.issuedDate = issuedDate
            alertIdentifier = alert.identifier.alertIdentifier
            managerIdentifier = alert.identifier.managerIdentifier
            triggerType = alert.trigger.storedType
            triggerInterval = alert.trigger.storedInterval
            interruptionLevel = alert.interruptionLevel
            // Encode as JSON strings
            let encoder = StoredAlert.encoder
            sound = try encoder.encodeToStringIfPresent(alert.sound)
            foregroundContent = try encoder.encodeToStringIfPresent(alert.foregroundContent)
            backgroundContent = try encoder.encodeToStringIfPresent(alert.backgroundContent)
        } catch {
            fatalError("Failed to encode: \(error)")
        }
    }

    public var trigger: Alert.Trigger {
        get {
            do {
                return try Alert.Trigger(storedType: triggerType, storedInterval: triggerInterval)
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
        let trigger = try Alert.Trigger(storedType: storedAlert.triggerType,
                                        storedInterval: storedAlert.triggerInterval,
                                        storageDate: adjustedForStorageTime ? storedAlert.issuedDate : nil)
        self.init(identifier: storedAlert.identifier,
                  foregroundContent: fgContent,
                  backgroundContent: bgContent,
                  trigger: trigger,
                  interruptionLevel: storedAlert.interruptionLevel,
                  sound: sound)
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

extension Alert.Trigger {
    enum StorageError: Error {
        case invalidStoredInterval, invalidStoredType
    }
    
    var storedType: Int16 {
        switch self {
        case .immediate: return 0
        case .delayed: return 1
        case .repeating: return 2
        }
    }
    var storedInterval: NSNumber? {
        switch self {
        case .immediate: return nil
        case .delayed(let interval): return NSNumber(value: interval)
        case .repeating(let repeatInterval): return NSNumber(value: repeatInterval)
        }
    }
    
    init(storedType: Int16, storedInterval: NSNumber?, storageDate: Date? = nil, now: Date = Date()) throws {
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
        default:
            throw StorageError.invalidStoredType
        }
    }
}

extension Alert.InterruptionLevel {
    enum StorageError: Error {
        case invalidStoredLevel
    }
    
    var storedValue: Int16 {
        // Since this is arbitrary anyway, might as well make it match iOS's values
        switch self {
        case .active:
            if #available(iOS 15.0, *) {
                return Int16(UNNotificationInterruptionLevel.active.rawValue)
            } else {
                return 1
            }
        case .timeSensitive:
            if #available(iOS 15.0, *) {
                return Int16(UNNotificationInterruptionLevel.timeSensitive.rawValue)
            } else {
                return 2
            }
        case .critical:
            if #available(iOS 15.0, *) {
                return Int16(UNNotificationInterruptionLevel.critical.rawValue)
            } else {
                return 3
            }
        }
    }
    
    init(storedValue: Int16) throws {
        switch storedValue {
        case Self.active.storedValue: self = .active
        case Self.timeSensitive.storedValue: self = .timeSensitive
        case Self.critical.storedValue: self = .critical
        default:
            throw StorageError.invalidStoredLevel
        }
    }
}



enum JSONEncoderError: Swift.Error {
    case stringEncodingError
}

fileprivate extension JSONEncoder {
    func encodeToStringIfPresent<T>(_ encodable: T?) throws -> String? where T: Encodable {
        guard let encodable = encodable else { return nil }
        let data = try self.encode(encodable)
        guard let result = String(data: data, encoding: .utf8) else {
            throw JSONEncoderError.stringEncodingError
        }
        return result
    }
}
