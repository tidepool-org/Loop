//
//  Color.swift
//  LoopUI
//
//  Created by Nathaniel Hamming on 2020-07-28.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

// MARK: - Color palette for common elements
extension Color {
    static let carbs = Color("carbs")
    
    static let fresh = Color("fresh")

    static let glucose = Color("glucose")
    
    static let insulin = Color("insulin")

    // The loopAccent color is intended to be use as the app accent color.
    public static let loopAccent = Color("accent")
    
    static public let warningColor = Color("warning")
}


// Color version of the UIColor context colors
extension Color {
    public static let agingColor = warningColor
    
    public static let axisLabelColor = secondary
    
    public static let axisLineColor = clear
    
    public static let cellBackgroundColor = Color(UIColor.cellBackgroundColor)
    
    public static let carbTintColor = carbs
    
    public static let criticalColor = red
    
    public static let destructive = criticalColor

    public static let doseTintColor = insulin
    
    public static let glucoseTintColor = glucose
    
    public static let gridColor = Color(UIColor.gridColor)

    public static let invalid = criticalColor

    public static let iobTintColor = insulin
    
    public static let pumpStatusNormal = insulin
    
    public static let staleColor = criticalColor
    
    public static let unknownColor = Color(UIColor.unknownColor)
}
