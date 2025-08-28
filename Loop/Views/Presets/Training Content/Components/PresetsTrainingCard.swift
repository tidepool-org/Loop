//
//  PresetsTrainingCard.swift
//  Loop
//
//  Created by Cameron Ingham on 8/27/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct PresetsTrainingCard: View {
    
    let imageName: String?
    
    init(trainingCompletion: PresetsTrainingCompletion) {
        if trainingCompletion.completedChapters[.introduction] != true {
            self.imageName = "PresetsTrainingRequiredCard"
        } else {
            self.imageName = nil
        }
    }
    
    var body: some View {
        if let imageName, let image = Image(imageName) {
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        }
    }
}
