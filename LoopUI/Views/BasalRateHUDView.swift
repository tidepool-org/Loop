//
//  BasalRateHUDView.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI

public final class BasalRateHUDView: BaseHUDView {
    
    override public var orderPriority: HUDViewOrderPriority {
        return 3
    }

    @IBOutlet private weak var treatmentArrowStateView: TreatmentArrowStateView!

    @IBOutlet private weak var basalRateLabel: UILabel! {
        didSet {
            basalRateLabel?.text = String(format: basalRateFormatString, "–")
            basalRateLabel?.textColor = .secondaryLabel

            accessibilityValue = LocalizedString("Unknown", comment: "Accessibility value for an unknown value")
        }
    }

    public override func tintColorDidChange() {
        super.tintColorDidChange()
        treatmentArrowStateView.tintColor = tintColor
    }

    private lazy var basalRateFormatString = LocalizedString("%@ U", comment: "The format string describing the basal rate.")

    public func setAutomatedTreatmentState(_ automatedTreatmentState: AutomatedTreatmentState) {
        treatmentArrowStateView.automatedTreatmentState = automatedTreatmentState
    }

    private lazy var decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.minimumIntegerDigits = 1
        formatter.positiveFormat = "+0.0##"
        formatter.negativeFormat = "-0.0##"

        return formatter
    }()

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return formatter
    }()

}
