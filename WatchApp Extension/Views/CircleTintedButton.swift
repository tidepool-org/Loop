//
//  CircleTintedButton.swift
//  Loop
//
//  Created by Pete Schwamb on 9/8/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct CircleTintedButton: View {
    @Environment(\.sizeClass) private var sizeClass

    var label: String
    var image: Image
    var foregroundTint: Color
    var backgroundTint: Color
    var action: () -> Void

    var buttonSize: CGFloat {
        if sizeClass.isLarge {
            return 64
        } else if sizeClass.isSmall {
            return 54
        } else {
            return 60
        }
    }

    var body: some View {
        ZStack {
            VStack {
                Button(action: action, label: {
                    image.foregroundStyle(foregroundTint)
                })
                .buttonStyle(CircleTintedButtonStyle(tint: backgroundTint))
                .frame(height: buttonSize)
                Text(label)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CircleTintedButtonStyle: ButtonStyle {
    var tint: Color
    @Environment(\.sizeClass) private var sizeClass

    func makeBody(configuration: Configuration) -> some View {
        backgroundShape
            .padding(.horizontal, sizeClass.hasRoundedCorners ? 4 : 0)
            .overlay(configuration.label)
            .padding(configuration.isPressed ? 1 : 0)
            .overlay(Color.black.opacity(configuration.isPressed ? 0.35 : 0))
    }

    private var backgroundShape: some View {
        Group {
            if sizeClass.hasRoundedCorners {
                Circle().fill(tint)
            } else {
                RoundedRectangle(cornerRadius: 6).fill(tint)
            }
        }
    }
}
