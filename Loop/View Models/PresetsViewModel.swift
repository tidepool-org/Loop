//
//  PresetsViewModel.swift
//  Loop
//
//  Created by Cameron Ingham on 10/23/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI

class PresetsViewModel: ObservableObject {
    
    // MARK: Training
    @AppStorage("hasCompletedPresetsTraining") var hasCompletedTraining: Bool = false
    @Published var showTraining: Bool = false
}
