//
//  PlayMediaButton.swift
//  Loop
//
//  Created by Cameron Ingham on 9/4/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct PlayMediaButton: View {

    let image: Image
    let title: Text
    let duration: TimeInterval
    
    private let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            image
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()
                .padding([.top, .horizontal], -8)
                .overlay {
                    Image("Play")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                }
            
            title
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ViewThatFits {
                HStack(spacing: 4) {
                    Text("Tap to listen")
                    Text("•")
                    Text(formatter.string(from: duration) ?? "")
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tap to listen")
                    Text(formatter.string(from: duration) ?? "")
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: .primary.opacity(0.2), radius: 3, x: 0, y: 0)
    }
}
