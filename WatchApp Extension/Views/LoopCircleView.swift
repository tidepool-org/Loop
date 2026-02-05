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

    private let closedLoop: Bool
    private let freshness: LoopCompletionFreshness
    private let deviceIssue: Bool
    
    public init(closedLoop: Bool, freshness: LoopCompletionFreshness, deviceIssue: Bool = false) {
        self.closedLoop = closedLoop
        self.freshness = freshness
        self.deviceIssue = deviceIssue
    }
    
    public var body: some View {
        GeometryReader { geometry in
            Circle()
                .trim(from: closedLoop ? 0 : 0.25, to: 1)
                .stroke(loopColor, lineWidth: geometry.size.height / 5)
                .rotationEffect(Angle(degrees: closedLoop ? -90 : -135))
                .animation(.default, value: closedLoop)
                .animation(.default, value: freshness)
        }
    }
    
    private var loopColor: Color {
        if !isEnabled {
            return .defaultWatchButtonGray
        } else if isEnabled && !deviceIssue && freshness == .fresh {
            return .fresh
        } else {
            return .gray
        }
    }
}
