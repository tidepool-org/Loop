//
//  CircularProgressWithCheckmark.swift
//  Loop
//
//  Created by Pete Schwamb on 9/23/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


import SwiftUI

struct CircularProgressWithCheckmark: View {
    let progress: CGFloat
    let isComplete: Bool

    var body: some View {
        ZStack {
            // Background circle (full gray ring)
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)

            // Progress arc (blue accent color)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-90)) // Start from top

            // Checkmark icon
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .opacity(isComplete ? 1 : 0)
        }
        .frame(width: 45, height: 45)
    }
}
