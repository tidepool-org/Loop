//
//  InsetContent.swift
//  Loop
//
//  Created by Cameron Ingham on 8/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct InsetContent<Content: View>: View {
    
    let alignment: HorizontalAlignment
    let content: () -> Content
    
    init(alignment: HorizontalAlignment = .center, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: 24) {
            content()
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.gray.quinary, lineWidth: 1)
        )
    }
}
