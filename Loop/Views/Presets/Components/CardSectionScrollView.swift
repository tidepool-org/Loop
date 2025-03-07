//
//  CardSectionScrollView.swift
//  Loop
//
//  Created by Pete Schwamb on 3/7/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct CardSectionScrollView<Content: View, ActionArea: View>: View {
    let content: Content
    let actionArea: ActionArea?

    // Initializer for custom view header
    init(@ViewBuilder content: () -> Content, @ViewBuilder actionArea: () -> ActionArea) {
        self.content = content()
        self.actionArea = actionArea()
    }

    // Initializer for no action area
    init(@ViewBuilder content: () -> Content) where ActionArea == Text {
        self.content = content()
        self.actionArea = nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading) {
                    content
                }
                .padding()
            }
            if let actionArea {
                VStack(spacing: 0) {
                    actionArea
                }
                .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
            }
        }
        .background(Color(.systemGroupedBackground))
        .edgesIgnoringSafeArea(actionArea == nil ? .bottom : [])
    }
}
