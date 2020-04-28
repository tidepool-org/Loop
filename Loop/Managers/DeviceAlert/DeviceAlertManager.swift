//
//  DeviceAlertManager.swift
//  Loop
//
//  Created by Rick Pasetto on 4/9/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

protocol DeviceAlertManagerResponder: class {
    /// Method for our Handlers to call to kick off alert response.  Differs from DeviceAlertResponder because here we need the whole `Identifier`.
    func acknowledgeDeviceAlert(identifier: DeviceAlert.Identifier)
}

/// Main (singleton-ish) class that is responsible for:
/// - managing the different targets (handlers) that will post alerts
/// - managing the different responders that might acknowledge the alert
/// - serializing alerts to storage
/// - etc.
public final class DeviceAlertManager {
    static let soundsDirectoryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).last!.appendingPathComponent("Sounds")
    
    private let log = DiagnosticLog(category: "DeviceAlertManager")

    var handlers: [DeviceAlertPresenter] = []
    var responders: [String: Weak<DeviceAlertResponder>] = [:]
    var soundVendors: [String: Weak<DeviceAlertSoundVendor>] = [:]

    public init(rootViewController: UIViewController,
                handlers: [DeviceAlertPresenter]? = nil) {
        self.handlers = handlers ??
            [UserNotificationDeviceAlertPresenter(),
            InAppModalDeviceAlertPresenter(rootViewController: rootViewController, deviceAlertManagerResponder: self)]
    }

    public func addAlertResponder(managerIdentifier: String, alertResponder: DeviceAlertResponder) {
        responders[managerIdentifier] = Weak(alertResponder)
    }
    
    public func removeAlertResponder(managerIdentifier: String) {
        responders.removeValue(forKey: managerIdentifier)
    }
    
    public func addAlertSoundVendor(managerIdentifier: String, soundVendor: DeviceAlertSoundVendor) {
        soundVendors[managerIdentifier] = Weak(soundVendor)
        initializeSoundVendor(managerIdentifier, soundVendor)
    }
    
    public func removeAlertSoundVendor(managerIdentifier: String) {
        soundVendors.removeValue(forKey: managerIdentifier)
    }
}

extension DeviceAlertManager: DeviceAlertManagerResponder {
    func acknowledgeDeviceAlert(identifier: DeviceAlert.Identifier) {
        if let responder = responders[identifier.managerIdentifier]?.value {
            responder.acknowledgeAlert(alertIdentifier: identifier.alertIdentifier)
        }
    }
}

extension DeviceAlertManager: DeviceAlertPresenter {

    public func issueAlert(_ alert: DeviceAlert) {
        handlers.forEach { $0.issueAlert(alert) }
    }
    public func removePendingAlert(identifier: DeviceAlert.Identifier) {
        handlers.forEach { $0.removePendingAlert(identifier: identifier) }
    }
    public func removeDeliveredAlert(identifier: DeviceAlert.Identifier) {
        handlers.forEach { $0.removeDeliveredAlert(identifier: identifier) }
    }
}

extension DeviceAlertManager {
    
    public static func soundURL(for alert: DeviceAlert) -> URL? {
        guard let soundName = alert.soundName else { return nil }
        return soundURL(managerIdentifier: alert.identifier.managerIdentifier, soundName: soundName)
    }
    
    private static func soundURL(managerIdentifier: String, soundName: DeviceAlert.SoundName) -> URL? {
        guard soundName != .vibrate && soundName != .silence else { return nil }
        
        // Seems all the sound files need to be in the sounds directory, so we namespace the filenames
        return soundsDirectoryURL.appendingPathComponent("\(managerIdentifier)-\(soundName.rawValue)")
    }
    
    private func initializeSoundVendor(_ managerIdentifier: String, _ soundVendor: DeviceAlertSoundVendor) {
        let soundFileNames = soundVendor.getSoundNames()
        guard let baseURL = soundVendor.getSoundBaseURL(), !soundFileNames.isEmpty else {
            return
        }
        do {
            let fileManager = FileManager.default
            try fileManager.createDirectory(atPath: DeviceAlertManager.soundsDirectoryURL.path, withIntermediateDirectories: true, attributes: nil)
            for soundName in soundFileNames where soundName != .vibrate && soundName != .silence {
                if let toURL = DeviceAlertManager.soundURL(managerIdentifier: managerIdentifier, soundName: soundName) {
                    try fileManager.copyIfNewer(from: baseURL.appendingPathComponent(soundName.rawValue), to: toURL)
                }
            }
        } catch {
            log.error("Unable to copy sound files from soundVendor %@: %@", managerIdentifier, String(describing: error))
        }
    }
    
}

extension FileManager {
    func copyIfNewer(from fromURL: URL, to toURL: URL) throws {
        if fileExists(atPath: toURL.path) {
            // If the source file is newer, remove the old one, otherwise skip it.
            let toCreationDate = try toURL.fileCreationDate()
            let fromCreationDate = try fromURL.fileCreationDate()
            if fromCreationDate > toCreationDate {
                try removeItem(at: toURL)
            } else {
                return
            }
        }
        try copyItem(at: fromURL, to: toURL)
    }
}

extension URL {
    
    func fileCreationDate() throws -> Date {
        return try FileManager.default.attributesOfItem(atPath: self.path)[.creationDate] as! Date
    }
}
