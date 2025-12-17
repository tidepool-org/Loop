//
//  LoopCircleView.swift
//  Loop
//
//  Created by Pete Schwamb on 9/8/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct LoopCircleView: View {
    
    @Environment(\.isEnabled) private var isEnabled
    
    private let animating: Bool
    private let closedLoop: Bool
    private let freshness: LoopCompletionFreshness
    private let deviceInoperable: Bool
    
    public init(closedLoop: Bool, freshness: LoopCompletionFreshness, animating: Bool = false, deviceInoperable: Bool = false) {
        self.closedLoop = closedLoop
        self.freshness = freshness
        self.animating = animating
        self.deviceInoperable = deviceInoperable
    }
    
    private var reversingAnimation: Animation {
        if animating && closedLoop {
            return .easeInOut(duration: 1).repeatForever(autoreverses: true)
        } else {
            return .easeInOut(duration: 1)
        }
    }
    
    public var body: some View {
        GeometryReader { geometry in
            Circle()
                .trim(from: closedLoop ? 0 : 0.2, to: 1)
                .stroke(loopColor, lineWidth: geometry.size.height / 5)
                .rotationEffect(Angle(degrees: closedLoop ? -90 : -126))
                .animation(.none, value: freshness)
                .animation(.default, value: closedLoop)
                .scaleEffect(animating && closedLoop ? 0.75 : 1)
                .animation(reversingAnimation, value: UUID())
        }
    }
    
    private var loopColor: Color {
        if !isEnabled {
            return .defaultWatchButtonGray
        } else if deviceInoperable {
            return .gray
        } else {
            switch freshness {
            case .fresh:
                return .fresh
            case .aging:
                return .gray
            case .stale:
                return .gray
            }
        }
    }
}
