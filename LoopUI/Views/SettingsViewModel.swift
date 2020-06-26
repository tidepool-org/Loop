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

public protocol SettingsViewModelDelegate: class {
    func onSettingsScreenDisplayed()

    var dosingEnabled: Bool { get set }
}

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
    
    var image: UIImage? { deviceManagerUI?.smallImage }
    // TODO: Remove the defaults here...they are only here for illustrative purposes
    var name: String { deviceManagerUI?.name ?? "device" }
    var details: String { deviceManagerUI?.details ?? "device details"  }
   
    let onTapped: () -> Void
}

public class SettingsViewModel: ObservableObject {
    
    weak var delegate: SettingsViewModelDelegate?
    let notificationsCriticalAlertPermissionsViewModel: NotificationsCriticalAlertPermissionsViewModel

    @Published var appNameAndVersion: String
    @State var dosingEnabled: Bool = false
    var showWarning: Bool {
        notificationsCriticalAlertPermissionsViewModel.showWarning
    }

    @ObservedObject var pumpManagerSettingsViewModel: DeviceViewModel
    @ObservedObject var cgmManagerSettingsViewModel: DeviceViewModel

    public init(appNameAndVersion: String,
                delegate: SettingsViewModelDelegate? = nil,
                notificationsCriticalAlertPermissionsViewModel: NotificationsCriticalAlertPermissionsViewModel,
                pumpManagerSettingsViewModel: DeviceViewModel,
                cgmManagerSettingsViewModel: DeviceViewModel) {
        self.delegate = delegate
        self.notificationsCriticalAlertPermissionsViewModel = notificationsCriticalAlertPermissionsViewModel
        self.appNameAndVersion = appNameAndVersion
        self.pumpManagerSettingsViewModel = pumpManagerSettingsViewModel
        self.cgmManagerSettingsViewModel = cgmManagerSettingsViewModel
    }

}
