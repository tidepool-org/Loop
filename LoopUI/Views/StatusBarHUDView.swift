//
//  StatusBarHUDView.swift
//  LoopUI
//
//  Created by Nathaniel Hamming on 2020-06-05.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKitUI

public class StatusBarHUDView: UIView, NibLoadable {
    
    @IBOutlet public weak var loopCompletionHUD: LoopCompletionHUDView!
    
    @IBOutlet public weak var cgmStatusContainer: CGMStatusContainerHUDView!
    
    @IBOutlet public weak var basalRateHUD: BasalRateHUDView!
        
    public var containerView: UIView!

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    func setup() {
        containerView = (StatusBarHUDView.nib().instantiate(withOwner: self, options: nil)[0] as! UIView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(containerView)

        // Use AutoLayout to have the stack view fill its entire container.
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: widthAnchor),
            containerView.heightAnchor.constraint(equalTo: heightAnchor),
        ])
        
        self.backgroundColor = UIColor.secondarySystemBackground
    }
    
    // TODO update based on the pump manager device specific reservoir view
    public func addHUDView(_ viewToAdd: BaseHUDView) {
        //NOP
    }
    
    // TODO the pump manager will only add a device specific reservoir view
    public func removePumpManagerProvidedViews() {
        let standardViews: [UIView] = [cgmStatusContainer, loopCompletionHUD, basalRateHUD]
        let pumpManagerViews = containerView.subviews.filter { !standardViews.contains($0) }
        for view in pumpManagerViews {
            view.removeFromSuperview()
        }
    }
}
