//
//  UIColor.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/23/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

// MARK: - Color palette for common elements
extension UIColor {
    @nonobjc static let carbs = UIColor(named: "carbs") ?? systemGreen

    @nonobjc static let critical = UIColor(named: "critical") ?? systemRed
    
    @nonobjc static let fresh = UIColor(named: "fresh") ?? systemGreen

    @nonobjc static let glucose = UIColor(named: "glucose") ?? systemTeal
    
    @nonobjc static let insulin = UIColor(named: "insulin") ?? systemOrange

    // The loopAccent color is intended to be use as the app accent color.
    @nonobjc static let loopAccent = UIColor(named: "accent") ?? systemBlue
    
    @nonobjc static let warning = UIColor(named: "warning") ?? systemYellow
}

// MARK: - Context for colors
extension UIColor {
    @nonobjc public static let agingColor = warning
    
    @nonobjc public static let axisLabelColor = secondaryLabel
    
    @nonobjc public static let axisLineColor = clear
    
    @nonobjc public static let cellBackgroundColor: UIColor = {
        if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
            return .secondarySystemBackground
        } else {
            return UIColor(white: 239 / 255, alpha: 1)
        }
    }()
    
    @nonobjc public static let cobTintColor = carbs
    
    @nonobjc public static let destructive = critical

    @nonobjc public static let doseTintColor = insulin
    
    @nonobjc public static let freshColor = fresh

    @nonobjc public static let glucoseTintColor = glucose
    
    @nonobjc public static let gridColor = systemGray3
    
    @nonobjc public static let invalid = critical

    @nonobjc public static let iobTintColor = insulin
    
    @nonobjc public static let pumpStatusNormal = insulin
    
    @nonobjc public static let staleColor = critical
    
    @nonobjc public static let unknownColor: UIColor = {
        if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
            return .systemGray4
        } else {
            return UIColor(red: 198 / 255, green: 199 / 255, blue: 201 / 255, alpha: 1)
        }
    }()
}
