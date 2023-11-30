//
//  DeviceDataManager+DeviceStatus.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2020-07-10.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import LoopCore

extension DeviceDataManager {
    @MainActor
    var cgmStatusHighlight: DeviceStatusHighlight? {
        let bluetoothState = bluetoothProvider.bluetoothState
        if bluetoothState == .unsupported || bluetoothState == .unauthorized {
            return BluetoothState.unavailableHighlight
        } else if bluetoothState == .poweredOff {
            return BluetoothState.offHighlight
        } else if cgmManager == nil {
            return DeviceDataManager.addCGMStatusHighlight
        } else {
            return (cgmManager as? CGMManagerUI)?.cgmStatusHighlight
        }
    }
    
    @MainActor
    var cgmStatusBadge: DeviceStatusBadge? {
        return (cgmManager as? CGMManagerUI)?.cgmStatusBadge
    }
    
    @MainActor
    var cgmLifecycleProgress: DeviceLifecycleProgress? {
        return (cgmManager as? CGMManagerUI)?.cgmLifecycleProgress
    }

    @MainActor
    var pumpStatusHighlight: DeviceStatusHighlight? {
        let bluetoothState = bluetoothProvider.bluetoothState
        if bluetoothState == .unsupported || bluetoothState == .unauthorized || bluetoothState == .poweredOff {
            return BluetoothState.enableHighlight
        } else if let onboardingManager = onboardingManager, !onboardingManager.isComplete, pumpManager?.isOnboarded != true {
            return DeviceDataManager.resumeOnboardingStatusHighlight
        } else if pumpManager == nil {
            return DeviceDataManager.addPumpStatusHighlight
        } else {
            return (pumpManager as? PumpManagerUI)?.pumpStatusHighlight
        }
    }

    @MainActor
    var pumpStatusBadge: DeviceStatusBadge? {
        return (pumpManager as? PumpManagerUI)?.pumpStatusBadge
    }

    @MainActor
    var pumpLifecycleProgress: DeviceLifecycleProgress? {
        return (pumpManager as? PumpManagerUI)?.pumpLifecycleProgress
    }
    
    static var resumeOnboardingStatusHighlight: ResumeOnboardingStatusHighlight {
        return ResumeOnboardingStatusHighlight()
    }

    struct ResumeOnboardingStatusHighlight: DeviceStatusHighlight {
        var localizedMessage: String = NSLocalizedString("Complete Setup", comment: "Title text for button to complete setup")
        var imageName: String = "exclamationmark.circle.fill"
        var state: DeviceStatusHighlightState = .warning
    }

    static var addCGMStatusHighlight: AddDeviceStatusHighlight {
        return AddDeviceStatusHighlight(localizedMessage: NSLocalizedString("Add CGM", comment: "Title text for button to set up a CGM"),
                                        state: .critical)
    }
    
    static var addPumpStatusHighlight: AddDeviceStatusHighlight {
        return AddDeviceStatusHighlight(localizedMessage: NSLocalizedString("Add Pump", comment: "Title text for button to set up a Pump"),
                                        state: .critical)
    }
    
    struct AddDeviceStatusHighlight: DeviceStatusHighlight {
        var localizedMessage: String
        var imageName: String = "plus.circle"
        var state: DeviceStatusHighlightState
    }
    
    func didTapOnCGMStatus(_ view: BaseHUDView? = nil) -> HUDTapAction? {
        if let action = bluetoothProvider.bluetoothState.action {
            return action
        } else if let url = cgmManager?.appURL,
            UIApplication.shared.canOpenURL(url)
        {
            return .openAppURL(url)
        } else if let cgmManagerUI = (cgmManager as? CGMManagerUI) {
            return .presentViewController(cgmManagerUI.settingsViewController(bluetoothProvider: bluetoothProvider, displayGlucosePreference: displayGlucosePreference, colorPalette: .default, allowDebugFeatures: FeatureFlags.allowDebugFeatures))
        } else {
            return .setupNewCGM
        }
    }
    
    @MainActor
    func didTapOnPumpStatus(_ view: BaseHUDView? = nil) -> HUDTapAction? {
        if let action = bluetoothProvider.bluetoothState.action {
            return action
        } else if let onboardingManager = onboardingManager, !onboardingManager.isComplete, pumpManager?.isOnboarded != true {
            onboardingManager.resume()
            return .takeNoAction
        } else if let pumpManagerHUDProvider = pumpManagerHUDProvider,
            let view = view,
            let action = pumpManagerHUDProvider.didTapOnHUDView(view, allowDebugFeatures: FeatureFlags.allowDebugFeatures)
        {
            return action
        } else if let pumpManager = pumpManager as? PumpManagerUI {
            return .presentViewController(pumpManager.settingsViewController(bluetoothProvider: bluetoothProvider, colorPalette: .default, allowDebugFeatures: FeatureFlags.allowDebugFeatures, allowedInsulinTypes: allowedInsulinTypes))
        } else {
            return .setupNewPump
        }
    }    
}

// MARK: - BluetoothState

fileprivate extension BluetoothState {
    struct Highlight: DeviceStatusHighlight {
        var localizedMessage: String
        var imageName: String = "bluetooth.disabled"
        var state: DeviceStatusHighlightState = .critical

        init(localizedMessage: String) {
            self.localizedMessage = localizedMessage
        }
    }

    static var offHighlight: Highlight {
        return Highlight(localizedMessage: NSLocalizedString("Bluetooth\nOff", comment: "Message to the user to that the bluetooth is off"))
    }

    static var enableHighlight: Highlight {
        return Highlight(localizedMessage: NSLocalizedString("Enable\nBluetooth", comment: "Message to the user to enable bluetooth"))
    }

    static var unavailableHighlight: Highlight {
        return Highlight(localizedMessage: NSLocalizedString("Bluetooth\nUnavailable", comment: "Message to the user that bluetooth is unavailable to the app"))
    }

    var action: HUDTapAction? {
        switch self {
        case .unauthorized:
            return .openAppURL(URL(string: UIApplication.openSettingsURLString)!)
        case .poweredOff:
            return .takeNoAction
        default:
            return nil
        }
    }
}
