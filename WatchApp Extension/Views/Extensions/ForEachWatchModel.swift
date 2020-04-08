//
//  ForEachWatchModel.swift
//  WatchPlayground WatchKit Extension
//
//  Created by Michael Pangburn on 3/24/20.
//  Copyright © 2020 Michael Pangburn. All rights reserved.
//

import SwiftUI


/// A helper to generate a preview for each Apple Watch device size.
struct ForEachWatchModel<Content: View>: View {
    private let deviceNames = [
        "Apple Watch Series 3 - 38mm",
        "Apple Watch Series 3 - 42mm",
        "Apple Watch Series 4 - 40mm",
        "Apple Watch Series 4 - 44mm"
    ]

    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ForEach(deviceNames, id: \.self) { deviceName in
            self.content
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName.components(separatedBy: "Apple Watch ").last!)
        }
    }
}
