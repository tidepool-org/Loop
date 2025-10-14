//
//  LoopStatusModalView.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2025-10-09.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI

struct LoopStatusModalView: View {
    @Environment(\.loopStatusColorPalette) private var loopStatusColors
    
    @State private var appear = false
    
    let viewModel: LoopStatusModalViewModel
    let message: String
    var onDismiss: () -> Void

    private var freshnessColor: Color {
        switch viewModel.freshness {
        case .fresh: return .primary
        case .aging: return Color(loopStatusColors.warning)
        case .stale: return Color(loopStatusColors.error)
        }
    }
    
    var body: some View {
        VStack {
            closeButton
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            LoopCircleView(closedLoop: viewModel.loopIconClosed, freshness: viewModel.freshness)
                .environment(\.loopStatusColorPalette, loopStatusColors)
                .padding(.bottom)
            
            if viewModel.loopIconClosed,
               let lastLoopCompletedFormattedTime = viewModel.lastLoopCompletedFormattedTime
            {
                lastLoopCompleted(lastLoopCompletedString: lastLoopCompletedFormattedTime)
            }
            
            automationDetails
                .padding([.top, .horizontal])
                .padding(.bottom, 10)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
        .frame(maxWidth: 300)
        .animation(.spring(), value: appear)
        .onAppear {
            withAnimation {
                appear = true
            }
        }
    }
    
    private var closeButton: some View {
        Button("\(Image(systemName: "xmark"))") {
            withAnimation(.spring()) {
                appear = false
            }
            // Dismiss after animation delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onDismiss()
            }
        }
        .foregroundStyle(.primary)
    }
    
    private func lastLoopCompleted(lastLoopCompletedString: String) -> some View {
        Group {
            Text("Last loop completed")
            Text("\(Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")) \(lastLoopCompletedString)")
                .foregroundStyle(freshnessColor)
        }
        .font(.footnote)
        .fontWeight(.semibold)
    }
    
    private var automationDetails: some View {
        VStack(alignment: .center) {
            automationTitle
            automationMessage
        }
    }
        
    private var automationTitle: some View {
        Text(viewModel.title)
            .font(.title2)
            .bold()
            .multilineTextAlignment(.center)
    }
    
    private var automationMessage: some View {
        Text(message)
            .multilineTextAlignment(.center)
    }
}

struct LoopStatusModalViewModel {
    private var timeAgoFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()

        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .short

        return formatter
    }()
    
    var freshness: LoopCompletionFreshness {
        LoopCompletionFreshness(age: ago)
    }
    var lastLoopCompleted: Date?
    var ago: TimeInterval? {
        guard let lastLoopCompleted else { return nil }
        return abs(min(0, lastLoopCompleted.timeIntervalSinceNow))
    }
    var loopIconClosed: Bool
    
    var title: String {
        guard loopIconClosed else {
            return NSLocalizedString("Automation is off", comment: "label for when automation is off")
        }
        
        if freshness == .fresh {
            return  NSLocalizedString("Automation is on", comment: "label for when automation is off")
        } else {
            return NSLocalizedString("Automation is unavailable", comment: "label for when automation is unavailable")
        }
    }
    
    var lastLoopCompletedFormattedTime: String? {
        guard let ago,
              let timeString = timeAgoFormatter.string(from: ago)
        else { return nil }
        
        return NSLocalizedString("\(timeString) ago", comment: "last loop completed string")
    }
    
    init(lastLoopCompleted: Date? = nil,
         loopIconClosed: Bool)
    {
        self.lastLoopCompleted = lastLoopCompleted
        self.loopIconClosed = loopIconClosed
    }
}
