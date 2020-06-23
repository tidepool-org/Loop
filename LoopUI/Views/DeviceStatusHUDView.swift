//
//  DeviceStatusHUDView.swift
//  LoopUI
//
//  Created by Nathaniel Hamming on 2020-06-05.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit
import LoopKitUI

@objc open class DeviceStatusHUDView: BaseHUDView {
    
    public var specialStatusView: SpecialStatusHUDView! {
        didSet {
            specialStatusView.isHidden = true
        }
    }
    
    @IBOutlet public weak var progressView: UIProgressView! {
        didSet {
            progressView.isHidden = true
        }
    }
    
    @IBOutlet public weak var backgroundView: UIView! {
        didSet {
            backgroundView.backgroundColor = .systemBackground
            backgroundView.layer.cornerRadius = 25
        }
    }
    
    @IBOutlet public weak var statusStackView: UIStackView!
    
    func setup() {
        if specialStatusView == nil {
            specialStatusView = SpecialStatusHUDView(frame: self.frame)
        }
    }
    
    func presentAlert() {
        statusStackView?.addArrangedSubview(specialStatusView)
        specialStatusView.isHidden = false
    }
    
    func dismissAlert() {
        // need to also hide this view, since it will be added back to the stack at some point
        specialStatusView.isHidden = true
        statusStackView?.removeArrangedSubview(specialStatusView)
    }
}
