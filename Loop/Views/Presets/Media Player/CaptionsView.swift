//
//  CaptionsView.swift
//  Podcast Demo
//
//  Created by Cameron Ingham on 3/21/25.
//

import LoopKit
import SwiftUI

struct CaptionsView: View {
    
    @Binding var currentTime: TimeInterval
    
    let captions: ClosedCaptions
    
    private var currentCaptionFragment: ClosedCaptionFragment? {
        captions.currentFragment(at: currentTime)
    }
    
    var body: some View {
        if let currentCaptionFragment {
            Text(currentCaptionFragment.text)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.white)
                .font(.subheadline)
                .padding(8)
                .background(Color.black.opacity(0.66).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)))
        }
    }
}
