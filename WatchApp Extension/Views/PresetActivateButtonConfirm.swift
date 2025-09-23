//
//  PresetActivateExtraConfirm.swift
//  Loop
//
//  Created by Pete Schwamb on 9/23/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopCore

struct PresetActivateButtonConfirm: View {
    @Environment(\.sizeClass) private var sizeClass

    let preset: SelectablePreset
    @Binding var confirmed: Bool

    private var actionButtonOffsetY: CGFloat {
        switch sizeClass {
        case .size38mm, .size42mm:
            return 0
        case .size40mm, .size41mm:
            return 20
        case .size44mm, .size45mm, .size46mm, .size49mm:
            return 27
        }
    }

    var body: some View {
        VStack {
            PresetDetailView(preset: preset)

            Spacer()

            ActionButton(
                title: Text("Start Preset", comment: "Button text to confirm starting preset before using digital crown"),
                color: .accentColor
            ) {
                confirmed = true
            }

        }
        .padding()
    }
}
