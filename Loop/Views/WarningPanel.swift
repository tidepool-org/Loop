//
//  WarningPanel.swift
//  Loop
//
//  Created by Pete Schwamb on 10/28/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI

struct WarningPanel<Content: View>: View {
    @Environment(\.guidanceColors) private var guidanceColors

    let severity: WarningSeverity
    @ViewBuilder let content: () -> Content

    init(severity: WarningSeverity = .default, @ViewBuilder _ content: @escaping () -> Content) {
        self.severity = severity
        self.content = content
    }

    var body: some View {
        let color: Color = severity > .default ? guidanceColors.critical : guidanceColors.warning

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(color)

            content()
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
