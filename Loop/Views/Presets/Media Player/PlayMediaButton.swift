//
//  PlayMediaButton.swift
//  Loop
//
//  Created by Cameron Ingham on 9/4/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

struct PlayMediaButton: View {

    let mediaContent: MediaContent
    var onPlay: (MediaContent) -> Void = { _ in }
    
    @State private var duration: TimeInterval = 0
    
    private let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    private var image: Image {
        Image(mediaContent.staticImage.name, bundle: mediaContent.staticImage.bundle)
    }
    
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
            
            Text(mediaContent.metadata.title)
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
        .task {
            self.duration = (try? await mediaContent.duration) ?? 0
        }
        .onTapGesture {
            onPlay(mediaContent)
        }
    }
}
