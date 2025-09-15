//
//  TintedContent.swift
//  Loop
//
//  Created by Cameron Ingham on 9/8/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

@Observable
private class TintColor {
    let color: Color
    
    init(color: Color) {
        self.color = color
    }
}

struct TintedContent<Content: View>: View {
        
    let tint: Color
    let icon: Image
    let title: Text
    let content: () -> Content
    
    init(
        tint: Color,
        icon: Image,
        title: Text,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tint = tint
        self.icon = icon
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                title
                    .font(.title2).bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } icon: {
                icon
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                content()
                    .environment(TintColor(color: tint))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(tint.opacity(0.1))
        )
    }
}

struct TintedTip: View {
    
    @Environment(TintColor.self) private var tintColor
    
    let text: Text
    
    var body: some View {
        text
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                tintColor.color
                    .cornerRadius(10)
                    .overlay(
                        Color(UIColor.systemBackground)
                            .cornerRadius(10)
                            .padding(.leading, 3)
                    )
            )
    }
}
