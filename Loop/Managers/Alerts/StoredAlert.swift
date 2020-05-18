//
//  StoredAlert.swift
//  Loop
//
//  Created by Rick Pasetto on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData
import LoopKit

enum StoredAlertRecordType: String {
    /// Recorded when the alert was _issued_ (note, a delayed alert is _issued_ when the delay starts, a repeating alert also is _issued_ when the alert starts repeating)
    case issued
    /// Recorded when an alert is _acknowledged_
    case acknowledged
    /// Recorded when an alert is _retracted_ (meaning, the alert condition is no longer true)
    case retracted
}

extension StoredAlert {
    
    convenience init(from deviceAlert: DeviceAlert, context: NSManagedObjectContext, timestamp: Date = Date()) {
        do {
            self.init(context: context)
            self.timestamp = timestamp
            managerIdentifier = deviceAlert.identifier.managerIdentifier
            alertIdentifier = deviceAlert.identifier.alertIdentifier
            // Encode as JSON strings
            let encoder = JSONEncoder()
            trigger = try encoder.encodeToStringIfPresent(deviceAlert.trigger)
            sound = try encoder.encodeToStringIfPresent(deviceAlert.sound)
            foregroundContent = try encoder.encodeToStringIfPresent(deviceAlert.foregroundContent)
            backgroundContent = try encoder.encodeToStringIfPresent(deviceAlert.backgroundContent)
            recordType = StoredAlertRecordType.issued.rawValue
            isCritical = deviceAlert.foregroundContent?.isCritical ?? false || deviceAlert.backgroundContent?.isCritical ?? false
        } catch {
            fatalError("Failed to encode: \(error)")
        }
    }
    
    convenience init(from identifier: DeviceAlert.Identifier, recordType: StoredAlertRecordType,
                     context: NSManagedObjectContext, timestamp: Date = Date()) {
        self.init(context: context)
        self.timestamp = timestamp
        managerIdentifier = identifier.managerIdentifier
        alertIdentifier = identifier.alertIdentifier
        self.recordType = recordType.rawValue
    }
}

fileprivate extension JSONEncoder {
    func encodeToStringIfPresent<T>(_ encodable: T?) throws -> String? where T: Encodable {
        guard let encodable = encodable else { return nil }
        let data = try self.encode(encodable)
        return String(data: data, encoding: .utf8)
    }
}
