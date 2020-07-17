//
//  UIColor.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/23/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import LoopKitUI

extension UIColor {
    @nonobjc public static let agingColor = UIColor.warning

    @nonobjc public static let axisLabelColor = secondaryLabel
    
    @nonobjc public static let axisLineColor = UIColor.clear
    
    @nonobjc public static let cellBackgroundColor: UIColor = {
        if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
            return .secondarySystemBackground
        } else {
            return UIColor(white: 239 / 255, alpha: 1)
        }
    }()
    
    @nonobjc public static let cobTintColor = UIColor.carbs

    @nonobjc public static let delete = UIColor.critical
    
    @nonobjc public static let doseTintColor = UIColor.insulin

    @nonobjc public static let freshColor = UIColor.carbs
    
    @nonobjc public static let glucoseTintColor = UIColor.glucose
    
    @nonobjc public static let gridColor: UIColor = {
        if #available(iOS 13.0, *) {
            return .systemGray3
        } else {
            return UIColor(red: 0 / 255, green: 176 / 255, blue: 255 / 255, alpha: 1)
        }
    }()
    
    @nonobjc public static let iobTintColor = UIColor.insulin
    
    @nonobjc public static let pumpStatusNormal = UIColor.insulin

    @nonobjc public static let staleColor = UIColor.critical

    @nonobjc public static let unknownColor: UIColor = {
        if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
            return .systemGray4
        } else {
            return UIColor(red: 198 / 255, green: 199 / 255, blue: 201 / 255, alpha: 1)
        }
    }()
}
