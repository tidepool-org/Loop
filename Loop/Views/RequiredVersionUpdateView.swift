//
//  RequiredVersionUpdateView.swift
//  Loop
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct RequiredVersionUpdateView: View {
    let appName: String
    let openAppStore: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                    .padding(.top, 8)

                Text(String(format: NSLocalizedString("Required %1$@ App Update", comment: "Title for required version update modal (1: app name)"), appName))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Text(String(format: NSLocalizedString("A critical issue has been discovered in this version of %1$@.", comment: "Required update modal paragraph 1 (1: app name)"), appName))
                    Text(String(format: NSLocalizedString("Until you update the app, you will not be able to use %1$@.", comment: "Required update modal paragraph 2 (1: app name)"), appName))
                    Text(NSLocalizedString("Please go to the App Store to install the latest version.", comment: "Required update modal paragraph 3"))
                }
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

                Divider()

                Button(action: openAppStore) {
                    Text(NSLocalizedString("App Store", comment: "Button title to open the App Store for a required update"))
                        .fontWeight(.semibold)
                }
                .padding(.bottom, 8)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(radius: 10)
            .padding(.horizontal, 40)
        }
    }
}
