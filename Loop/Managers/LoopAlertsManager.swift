//
//  LoopAlertsManager.swift
//  Loop
//
//  Created by Rick Pasetto on 6/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreBluetooth
import LoopKit

/// Class responsible for monitoring "system level" operations and alerting the user to any anomalous situations (e.g. bluetooth off)
class LoopAlertsManager: NSObject {
    private var bluetoothCentralManager: CBCentralManager!
    private lazy var log = DiagnosticLog(category: String(describing: LoopAlertsManager.self))
    private weak var alertManager: AlertManager?
    private let bluetoothPoweredOffIdentifier = Alert.Identifier(managerIdentifier: "Loop", alertIdentifier: "bluetoothPoweredOff")

    init(deviceAlertManager: AlertManager) {
        super.init()
        bluetoothCentralManager = CBCentralManager(delegate: self, queue: nil)
        self.alertManager = deviceAlertManager
    }
}

// MARK: CBCentralManagerDelegate implementation

extension LoopAlertsManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unauthorized:
            switch central.authorization {
            case .allowedAlways: break
            case .denied: break
            case .restricted: break
            case .notDetermined: break
            @unknown default: break
            }
        case .unknown: break
        case .unsupported: break
        case .poweredOn:
            onBluetoothPoweredOn()
        case .poweredOff:
            onBluetoothPoweredOff()
        case .resetting: break
        @unknown default: break
        }
    }
    
    private func onBluetoothPoweredOn() {
        log.default("Bluetooth powered on")
        alertManager?.retractAlert(identifier: bluetoothPoweredOffIdentifier)
    }

    private func onBluetoothPoweredOff() {
        log.default("Bluetooth powered off")
        let bgcontent = Alert.Content(title: NSLocalizedString("Bluetooth Off Alert", comment: "Bluetooth off background alert title"),
                                      body: NSLocalizedString("Turn on Bluetooth to receive alerts, alarms or sensor glucose readings.", comment: "Bluetooth off alert body"),
                                      acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "Default alert dismissal"))
        let fgcontent = Alert.Content(title: NSLocalizedString("Bluetooth Off", comment: "Bluetooth off foreground alert title"),
                                      body: NSLocalizedString("Turn on Bluetooth to receive alerts, alarms or sensor glucose readings.", comment: "Bluetooth off alert body"),
                                      acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "Default alert dismissal"))
        alertManager?.issueAlert(Alert(identifier: bluetoothPoweredOffIdentifier, foregroundContent: fgcontent, backgroundContent: bgcontent, trigger: .immediate))
    }

}
