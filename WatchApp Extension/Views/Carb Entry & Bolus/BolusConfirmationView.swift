//
//  BolusConfirmationView.swift
//  WatchApp Extension
//
//  Created by Michael Pangburn on 3/27/20.
//  Copyright © 2020 Michael Pangburn. All rights reserved.
//

import Combine
import SwiftUI


struct BolusConfirmationView: View {
    // Strictly for storage. Use `progress` to access the underlying value.
    @State private var progressStorage: Double = 0

    private let completion: () -> Void
    private let resetProgress = PeriodicPublisher(interval: 0.25)

    private var progress: Binding<Double> {
        Binding(
            get: { self.progressStorage.clamped(to: 0...1) },
            set: { newValue in
                // Prevent further state changes after completion.
                guard self.progressStorage < 1.0 else {
                    return
                }

                withAnimation {
                    self.progressStorage = newValue
                }

                self.resetProgress.acknowledge()
                if newValue >= 1.0 {
                    WKInterfaceDevice.current().play(.success)
                    self.completion()
                }
            }
        )
    }

    init(onConfirmation completion: @escaping () -> Void) {
        self.completion = completion
    }

    var body: some View {
        VStack(spacing: 8) {
            BolusConfirmationVisual(progress: progressStorage)
            helpText
        }
        .focusable()
        // By experimentation, it seems that 0...1 with low rotational sensitivty requires only 1/4 of one rotation.
        // Scale accordingly.
        .digitalCrownRotation(
            progress,
            over: 0...1,
            sensitivity: .low,
            scalingRotationBy: 4
        )
        .onReceive(resetProgress) {
            self.progress.wrappedValue = 0
        }
    }

    private var isFinished: Bool { progressStorage >= 1.0 }

    private var helpText: some View {
        Text("Turn Digital Crown\nto bolus")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundColor(Color(.lightGray))
            .fixedSize(horizontal: false, vertical: true)
            .opacity(isFinished ? 0 : 1)
    }
}
