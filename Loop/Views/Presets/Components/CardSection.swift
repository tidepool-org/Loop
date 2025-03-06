//
//  CardSection.swift
//  Loop
//
//  Created by Pete Schwamb on 3/6/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

// Simple rounded card view with arbitrary content. Can be used to make screens that look like grouped section table views,
// that need to animate height (List/TableViews have problems with resizing views and animating them). Similar to Card in
// LoopKitUI, but unlike Card, has requirement on the type of content except that it is a View.

struct CardSection<Content: View>: View {
    let content: Content

    // Initializer for custom view header
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(Color(UIColor.tertiarySystemBackground))
            .frame(maxWidth: .infinity))
        .padding(.top, 10)
        .clipped()
    }
}

