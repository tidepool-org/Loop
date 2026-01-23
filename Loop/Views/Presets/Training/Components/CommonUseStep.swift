//
//  CommonUseStep.swift
//  Loop
//
//  Created by Cameron Ingham on 9/2/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct CommonUseStep: View {
    
    @Environment(\.isEnabled) private var isEnabled
    
    private let title: Text
    private let readTimeString: String
    private let onTapGesture: (() -> Void)?
    
    private let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .short
        return formatter
    }()
    
    init?(
        title: Text,
        readTime: TimeInterval,
        onTapGesture: (() -> Void)? = nil
    ) {
        self.title = title
        
        guard let readTimeString = formatter.string(from: readTime) else {
            return nil
        }
        
        self.readTimeString = readTimeString
        self.onTapGesture = onTapGesture
    }
    
    init?(
        title: String,
        readTime: TimeInterval,
        onTapGesture: (() -> Void)? = nil
    ) {
        self.init(
            title: Text(title),
            readTime: readTime,
            onTapGesture: onTapGesture
        )
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                title
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("\(readTimeString) read")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 16)
            
            Image(systemName: isEnabled && onTapGesture == nil ? "checkmark.circle.fill" : "circle")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.accentColor)
        }
        .padding(16)
        .background(
            Color(UIColor.systemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        )
        .shadow(
            color: .primary.opacity(0.03),
            radius: 6,
            x: 0,
            y: 4
        )
        .opacity(isEnabled ? 1 : 0.6)
        .onTapGesture {
            onTapGesture?()
        }
    }
}
