//
//  PumpStatusHUDView.swift
//  LoopUI
//
//  Created by Nathaniel Hamming on 2020-06-09.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit
import LoopKitUI

public final class PumpStatusHUDView: DeviceStatusHUDView, NibLoadable {
    
    @IBOutlet public weak var basalRateHUD: BasalRateHUDView!
    
    @IBOutlet public weak var pumpManagerProvidedHUD: LevelHUDView!
        
    override public var orderPriority: HUDViewOrderPriority {
        return 3
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override func setup() {
        super.setup()
        statusMessageView.setIconPosition(.left)
    }
    
    public override func tintColorDidChange() {
        super.tintColorDidChange()
        
        basalRateHUD.tintColor = tintColor
        pumpManagerProvidedHUD?.tintColor = tintColor
    }
    
    public func presentAddPumpMessage() {
        statusMessageView.messageLabel.text = LocalizedString("Add Pump", comment: "Title text for button to set up a pump")
        statusMessageView.messageLabel.tintColor = .label
        statusMessageView.messageIcon.image = UIImage(systemName: "plus.circle")
        statusMessageView.messageIcon.tintColor = .systemBlue
        presentMessage()
    }
    
    override public func presentMessage() {
        guard !statusStackView.arrangedSubviews.contains(statusMessageView) else {
            return
        }
        
        // need to also hide these view, since they will be added back to the stack at some point
        basalRateHUD.isHidden = true
        statusStackView.removeArrangedSubview(basalRateHUD)
        
        if let pumpManagerProvidedHUD = pumpManagerProvidedHUD {
            pumpManagerProvidedHUD.isHidden = true
            statusStackView.removeArrangedSubview(pumpManagerProvidedHUD)
        }

        super.presentMessage()
    }
    
    override public func dismissMessage() {
        guard statusStackView.arrangedSubviews.contains(statusMessageView) else {
            return
        }
        
        super.dismissMessage()
        
        statusStackView.addArrangedSubview(basalRateHUD)
        basalRateHUD.isHidden = false
        
        if let pumpManagerProvidedHUD = pumpManagerProvidedHUD {
            statusStackView.addArrangedSubview(pumpManagerProvidedHUD)
            pumpManagerProvidedHUD.isHidden = false
        }
    }
    
    public func removePumpManagerProvidedHUD() {
        guard let pumpManagerProvidedHUD = pumpManagerProvidedHUD else {
            return
        }
        
        statusStackView.removeArrangedSubview(pumpManagerProvidedHUD)
        pumpManagerProvidedHUD.removeFromSuperview()
    }
    
    public func addPumpManagerProvidedHUDView(_ pumpManagerProvidedHUD: LevelHUDView) {
        self.pumpManagerProvidedHUD = pumpManagerProvidedHUD
        statusStackView.addArrangedSubview(self.pumpManagerProvidedHUD)
        
        // Use AutoLayout to have the reservoir volume view fill 2/5 of the stack view (fill proportionally)
        NSLayoutConstraint.activate([
            self.pumpManagerProvidedHUD.widthAnchor.constraint(equalToConstant: statusStackView.frame.width*2/5)
        ])
    }
    
}
