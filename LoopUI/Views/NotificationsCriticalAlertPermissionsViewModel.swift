//
//  NotificationsCriticalAlertPermissionsViewModel.swift
//  LoopUI
//
//  Created by Rick Pasetto on 6/11/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftUI

public class NotificationsCriticalAlertPermissionsViewModel {
    public init() { }
    
    public func gotoSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}
