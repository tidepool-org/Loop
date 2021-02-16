//
//  StatusBadgeHUDView.swift
//  LoopUI
//
//  Created by Nathaniel Hamming on 2021-02-11.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import UIKit
//import HealthKit
//import LoopKit
//import LoopKitUI

public final class StatusBadgeHUDView: UIView {
    
    @IBOutlet private weak var badgeIcon: UIImageView! {
        didSet {
            // badge color design is currently always the warning color
            badgeIcon.tintColor = .warning
        }
    }
    
    public func setBadgeIcon(_ icon: UIImage?) {
        badgeIcon.image = icon
    }
}
