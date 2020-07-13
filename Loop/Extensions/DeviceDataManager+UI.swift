//
//  DeviceDataManager+UI.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2020-07-08.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import LoopKitUI

extension DeviceDataManager {
    var pumpStatusHighlight: DeviceStatusHighlight? {
        if let bluetoothStatusHighlight = bluetoothState.statusHighlight {
            return bluetoothStatusHighlight
        } else if pumpManager == nil {
            return DeviceDataManager.addPumpStatusHighlight
        } else {
            return pumpManagerStatus?.pumpStatusHighlight
        }
    }
    
    var pumpLifecycleProgress: DeviceLifecycleProgress? {
        return pumpManagerStatus?.pumpLifecycleProgress
    }
    
    var cgmStatusHighlight: DeviceStatusHighlight? {
        if let bluetoothStatusHighlight = bluetoothState.statusHighlight {
            return bluetoothStatusHighlight
        } else if cgmManager == nil {
            return DeviceDataManager.addCGMStatusHighlight
        } else {
            return (cgmManager as? CGMManagerUI)?.cgmStatusHighlight
        }
    }
    
    var cgmLifecycleProgress: DeviceLifecycleProgress? {
        return (cgmManager as? CGMManagerUI)?.cgmLifecycleProgress
    }
    
    static var addCGMStatusHighlight: AddDeviceStatusHighlight {
        return AddDeviceStatusHighlight(localizedMessage: NSLocalizedString("Add CGM", comment: "Title text for button to set up a CGM"))
    }
    
    static var addPumpStatusHighlight: AddDeviceStatusHighlight {
        return AddDeviceStatusHighlight(localizedMessage: NSLocalizedString("Add Pump", comment: "Title text for button to set up a Pump"))
    }
    
    struct AddDeviceStatusHighlight: DeviceStatusHighlight {
        var localizedMessage: String
        var imageSystemName: String = "plus.circle"
        var state: DeviceStatusHighlightState = .normal
    }
    
    func didTapOnPumpStatus() -> DeviceStatusAction? {
        if let action = bluetoothState.action {
            return action
        } else if let pumpManager = pumpManager {
            return .presentViewController(pumpManager.settingsViewController())
        } else {
            return .setupNewPump
        }
    }
    
    func didTapOnCGMStatus() -> DeviceStatusAction? {
        if let action = bluetoothState.action {
            return action
        } else if let cgmManagerUI = (cgmManager as? CGMManagerUI),
            let unit = loopManager.glucoseStore.preferredUnit
        {
            return .presentViewController(cgmManagerUI.settingsViewController(for: unit))
        } else {
            return .setupNewCGM
        }
    }
}

public enum DeviceStatusAction {
    case presentViewController(UIViewController & CompletionNotifying)
    case openAppURL(URL)
    case setupNewPump
    case setupNewCGM
    case takeNoAction
}
