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
    static let loopAccent = Color("accent")
    
    static let warning = Color("warning")
}


// Color version of the UIColor context colors
extension Color {
    public static let agingColor = warning
    
    public static let axisLabelColor = secondary
    
    public static let axisLineColor = clear
    
    public static let cellBackgroundColor = Color(UIColor.cellBackgroundColor)
    
    public static let cobTintColor = carbs
    
    public static let critical = red
    
    public static let destructive = critical

    public static let doseTintColor = insulin
    
    public static let glucoseTintColor = glucose
    
    public static let gridColor = Color(UIColor.gridColor)

    public static let invalid = critical

    public static let iobTintColor = insulin
    
    public static let pumpStatusNormal = insulin
    
    public static let staleColor = critical
    
    public static let unknownColor = Color(UIColor.unknownColor)
}
