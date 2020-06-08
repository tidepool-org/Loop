//
//  AlertStatusHUDView.swift
//  LoopUI
//
//  Created by Nathaniel Hamming on 2020-06-05.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

public class AlertStatusHUDView: UIView, NibLoadable {
    
    private var containerView: UIView!
    
    @IBOutlet public weak var alertMessageLabel: UILabel!
    
    @IBOutlet public weak var alertIcon: UIImageView! {
        didSet {
            alertIcon.tintColor = tintColor
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    func setup() {
        containerView = (AlertStatusHUDView.nib().instantiate(withOwner: self, options: nil)[0] as! UIView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(containerView)

        // Use AutoLayout to have the stack view fill its entire container.
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: widthAnchor),
            containerView.heightAnchor.constraint(equalTo: heightAnchor),
        ])
    }
}
