//
//  StoredAlert.swift
//  Loop
//
//  Created by Rick Pasetto on 5/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreData
import LoopKit

extension StoredAlert {
    
    static var encoder = JSONEncoder()
          
    convenience init(from deviceAlert: DeviceAlert, context: NSManagedObjectContext, issuedDate: Date = Date()) {
        do {
            self.init(context: context)
            self.issuedDate = issuedDate
            identifier = deviceAlert.identifier.value
            // Encode as JSON strings
            let encoder = StoredAlert.encoder
            trigger = try encoder.encodeToStringIfPresent(deviceAlert.trigger)
            sound = try encoder.encodeToStringIfPresent(deviceAlert.sound)
            foregroundContent = try encoder.encodeToStringIfPresent(deviceAlert.foregroundContent)
            backgroundContent = try encoder.encodeToStringIfPresent(deviceAlert.backgroundContent)
            isCritical = deviceAlert.foregroundContent?.isCritical ?? false || deviceAlert.backgroundContent?.isCritical ?? false
        } catch {
            fatalError("Failed to encode: \(error)")
        }
    }

    public override func willSave() {
        if isInserted || isUpdated {
            setPrimitiveValue(managedObjectContext!.modificationCounter ?? 0, forKey: "modificationCounter")
        }
        super.willSave()
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
