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
                    .foregroundColor(.critical)
                    .padding(.top, 8)

                Text(String(format: NSLocalizedString("Required %1$@ App Update", comment: "Title for required version update modal (1: app name)"), appName))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Text(String(format: NSLocalizedString("A critical issue has been discovered in this version of %1$@. To continue using the app, you must update to the latest version.", comment: "Required update modal paragraph 1 (1: app name)"), appName))
                    Text(String(format: NSLocalizedString("You will continue to receive your scheduled basal rate, but %1$@ will not make automated adjustments.", comment: "Required update modal paragraph 2 (1: app name)"), appName))
                    Text(NSLocalizedString("Please go to the App Store now to update the app.", comment: "Required update modal paragraph 3"))
                }
                .font(.subheadline)
                .multilineTextAlignment(.center)

                Divider()
                    .padding(.horizontal, -40)

                Button(action: openAppStore) {
                    Text(NSLocalizedString("App Store", comment: "Button title to open the App Store for a required update"))
                        .font(.title3)
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
