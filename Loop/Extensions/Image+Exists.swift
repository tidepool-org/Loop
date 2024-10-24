//
//  Image+Exists.swift
//  Loop
//
//  Created by Cameron Ingham on 10/23/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit

extension Image {
    static func imageExists(_ name: String, in bundle: Bundle? = nil, with configuration: UIImage.Configuration? = nil) -> Bool {
        UIImage(named: name, in: bundle, with: configuration) != nil
    }
}
