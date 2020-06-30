//
//  LoopAlertsManager.swift
//  Loop
//
//  Created by Rick Pasetto on 6/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import CoreBluetooth
import LoopKit


public protocol LoopAlertsManagerBluetoothStateObserver: class {
    func loopAlertsManager(_ loopAlertsManager: LoopAlertsManager, bluetoothStateDidUpdate bluetoothState: LoopAlertsManager.BluetoothState)
}

/// Class responsible for monitoring "system level" operations and alerting the user to any anomalous situations (e.g. bluetooth off)
public class LoopAlertsManager: NSObject {
    
    public enum BluetoothState {
        case on
        case off
        case unauthorized
    }
    
    static let managerIdentifier = "Loop"
    
    private var bluetoothCentralManager: CBCentralManager!
    
    private lazy var log = DiagnosticLog(category: String(describing: LoopAlertsManager.self))
    
    private weak var alertManager: AlertManager?
    
    private let bluetoothPoweredOffIdentifier = Alert.Identifier(managerIdentifier: managerIdentifier, alertIdentifier: "bluetoothPoweredOff")

    private var bluetoothStateObservers = WeakSynchronizedSet<LoopAlertsManagerBluetoothStateObserver>()
    
    private var bluetoothState: BluetoothState = .off
    
    init(alertManager: AlertManager) {
        super.init()
        bluetoothCentralManager = CBCentralManager(delegate: self, queue: nil)
        self.alertManager = alertManager
    }
    
    public func addBluetoothStateObserver(_ observer: LoopAlertsManagerBluetoothStateObserver,
                                     queue: DispatchQueue = .main)
    {
        bluetoothStateObservers.insert(observer, queue: queue)
    }
    
    public func removeBluetoothStateObserver(_ observer: LoopAlertsManagerBluetoothStateObserver) {
        bluetoothStateObservers.removeElement(observer)
    }
}

// MARK: CBCentralManagerDelegate implementation

extension LoopAlertsManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unauthorized:
            bluetoothState = .unauthorized
            switch central.authorization {
            case .denied:
                onBluetoothPermissionDenied()
            default:
                break
            }
        case .poweredOn:
            onBluetoothPoweredOn()
            bluetoothState = .on
        case .poweredOff:
            onBluetoothPoweredOff()
            bluetoothState = .off
        case .unsupported:
            // to support the iphone simulator
            #if DEBUG
            bluetoothState = .on
            #endif
        default:
            bluetoothState = .off
            break
        }
        bluetoothStateObservers.forEach { $0.loopAlertsManager(self, bluetoothStateDidUpdate: self.bluetoothState) }
    }
    
    private func onBluetoothPermissionDenied() {
        log.default("Bluetooth permission denied")
        let content = Alert.Content(title: NSLocalizedString("Bluetooth Permission Denied", comment: "Bluetooth permission denied alert title"),
                                      body: NSLocalizedString("Loop needs permission to access your iPhone’s Bluetooth connection in order for the app to communicate with your pump and CGM sensor. You will be unable to use the app to receive CGM information and send commands to your pump until Bluetooth permissions are enabled.",
                                                              comment: "Bluetooth permission denied alert body"),
                                      acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "Default alert dismissal"))
        alertManager?.issueAlert(Alert(identifier: bluetoothPoweredOffIdentifier, foregroundContent: content, backgroundContent: content, trigger: .immediate))
    }

    private func onBluetoothPoweredOn() {
        log.default("Bluetooth powered on")
        alertManager?.retractAlert(identifier: bluetoothPoweredOffIdentifier)
    }

    private func onBluetoothPoweredOff() {
        log.default("Bluetooth powered off")
        let body = NSLocalizedString("You have turned Bluetooth off. Loop cannot communicate with your pump and CGM sensor when Bluetooth is off. To resume automation, turn Bluetooth on.", comment: "Bluetooth off alert body")
        let bgcontent = Alert.Content(title: NSLocalizedString("Bluetooth Off Alert", comment: "Bluetooth off background alert title"),
                                      body: body,
                                      acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "Default alert dismissal"))
        let fgcontent = Alert.Content(title: NSLocalizedString("Bluetooth Off", comment: "Bluetooth off foreground alert title"),
                                      body: body,
                                      acknowledgeActionButtonLabel: NSLocalizedString("OK", comment: "Default alert dismissal"))
        alertManager?.issueAlert(Alert(identifier: bluetoothPoweredOffIdentifier, foregroundContent: fgcontent, backgroundContent: bgcontent, trigger: .immediate))
    }

}


// MARK: - Bluetooth Status Highlight
extension LoopAlertsManager {
    struct BluetoothStateHighlight: DeviceStatusHighlight {
        var localizedMessage: String
        //TODO need correct icon from design
        var icon: UIImage = UIImage(systemName: "wifi.slash")!
        var color: UIColor = .systemRed
        
        init(localizedMessage: String) {
            self.localizedMessage = localizedMessage
        }
    }
    
    public static var bluetoothStateOffHighlight: DeviceStatusHighlight {
        return BluetoothStateHighlight(localizedMessage: NSLocalizedString("Enable Bluetooth", comment: "Message to the user to enable bluetooth"))
    }
    
    public static var bluetoothStateUnauthorizedHighlight: DeviceStatusHighlight {
        return BluetoothStateHighlight(localizedMessage: NSLocalizedString("Allow Bluetooth", comment: "Message to the user to allow bluetooth"))
    }
}
