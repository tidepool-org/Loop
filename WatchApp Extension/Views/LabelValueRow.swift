//
//  LabelValueRow.swift
//  Loop
//
//  Created by Pete Schwamb on 9/20/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct LabelValueRow: View {
    let label: LocalizedStringKey
    let value: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value ?? "–")
                .font(.title3)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
