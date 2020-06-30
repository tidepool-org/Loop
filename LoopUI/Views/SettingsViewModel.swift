//
//  SettingsViewModel.swift
//  LoopUI
//
//  Created by Rick Pasetto on 6/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import LoopCore
import LoopKit
import LoopKitUI
import SwiftUI

public class DeviceViewModel: ObservableObject {
    public init(deviceManagerUI: DeviceManagerUI.Type? = nil,
                isSetUp: Bool = true,
                onTapped: @escaping () -> Void = { }) {
        self.deviceManagerUI = deviceManagerUI
        self.isSetUp = isSetUp
        self.onTapped = onTapped
    }
    
    let deviceManagerUI: DeviceManagerUI.Type?

    @Published private(set) var isSetUp: Bool = false
    
    var image: UIImage? { deviceManagerUI?.image }
    // TODO: Remove the defaults here...they are only here for illustrative purposes
    var name: String { deviceManagerUI?.name ?? "device" }
    var details: String { deviceManagerUI?.details ?? "device details"  }
   
    let onTapped: () -> Void
}

public class SettingsViewModel: ObservableObject {
    
    let notificationsCriticalAlertPermissionsViewModel: NotificationsCriticalAlertPermissionsViewModel

    @Published var appNameAndVersion: String
    @Published var dosingEnabled: Bool = false {
        didSet {
            dosingEnabledChanged?(dosingEnabled)
        }
    }
    private let dosingEnabledChanged: ((Bool) -> Void)?
    
    var showWarning: Bool {
        notificationsCriticalAlertPermissionsViewModel.showWarning
    }

    @ObservedObject var pumpManagerSettingsViewModel: DeviceViewModel
    @ObservedObject var cgmManagerSettingsViewModel: DeviceViewModel

    public init(appNameAndVersion: String,
                notificationsCriticalAlertPermissionsViewModel: NotificationsCriticalAlertPermissionsViewModel,
                pumpManagerSettingsViewModel: DeviceViewModel,
                cgmManagerSettingsViewModel: DeviceViewModel,
                // TODO: This is temporary until I can figure out something cleaner
                initialDosingEnabled: Bool,
                dosingEnabledChanged: ((Bool) -> Void)? = nil
                ) {
        self.notificationsCriticalAlertPermissionsViewModel = notificationsCriticalAlertPermissionsViewModel
        self.appNameAndVersion = appNameAndVersion
        self.pumpManagerSettingsViewModel = pumpManagerSettingsViewModel
        self.cgmManagerSettingsViewModel = cgmManagerSettingsViewModel
        self.dosingEnabledChanged = dosingEnabledChanged
        self.dosingEnabled = initialDosingEnabled
    }

}
