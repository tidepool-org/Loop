//
//  PresetsTrainingView.swift
//  Loop
//
//  Created by Cameron Ingham on 8/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import SwiftUI

struct PresetsTrainingView: View {
    
    @Environment(\.appName) private var appName
    @Environment(\.colorPalette) private var colorPalette
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    
    @Bindable private var training: PresetsTraining
    
    @State private var confirmDismiss: Bool = false
    
    init(trainingCompletion: PresetsTrainingCompletion) {
        self.training = PresetsTraining(trainingCompletion: trainingCompletion)
    }
    
    @ViewBuilder
    private var closeButton: some View {
        Button("Close") {
            if training.trainingCompletion.isComplete {
                close()
            } else if training.trainingCompletion.completedChapters[.entry] != true {
                training.trainingCompletion.completedChapters[.entry] = true
                close()
            } else {
                confirmDismiss = true
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $training.navigationPath) {
            stepView(training.startingAt.firstStep)
                .navigationDestination(for: PresetsTraining.Step.self) { step in
                    stepView(step)
                }
        }
        .environment(training)
        .interactiveDismissDisabled(!training.trainingCompletion.isComplete)
    }
    
    private func close() {
        dismiss()
    }
    
    @ViewBuilder
    private func stepView(_ step: PresetsTraining.Step) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 8) {
                        Text(step.title(appName: appName))
                            .font(.largeTitle.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                        
                        Divider()
                    }
                    .padding(.bottom, 24)
                    
                    step.content(appName: appName, displayGlucosePreference: displayGlucosePreference, colorPalette: colorPalette)
                        .padding(.bottom, 24)
                        .padding(.horizontal, 16)
                    
                    if let cta = step.cta {
                        Spacer(minLength: 0)
                        
                        Group {
                            switch cta {
                            case .start:
                                Button("Start Required Training") {
                                    training.next()
                                }
                                .buttonStyle(ActionButtonStyle())
                            case .continue:
                                Button("Continue") {
                                    training.next()
                                }
                                .buttonStyle(ActionButtonStyle())
                            case .closeOrContinue(let continueTo, let chapter):
                                VStack(spacing: 12) {
                                    Button("Close Training") {
                                        if training.trainingCompletion.completedChapters[chapter] != true {
                                            training.trainingCompletion.completedChapters[chapter] = true
                                        }
                                        
                                        close()
                                    }
                                    .buttonStyle(ActionButtonStyle(.secondary))
                                    
                                    Button("Continue to \(continueTo)") {
                                        training.next()
                                    }
                                    .buttonStyle(ActionButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                closeButton
            }
        }
        .alert(isPresented: $confirmDismiss) {
            Alert(
                title: Text("End Training?"),
                message: Text("You’ll have to restart this section and some features will be disabled until you complete the training."),
                primaryButton: .cancel(),
                secondaryButton: .destructive(Text("End"), action: { close() })
            )
        }
    }
}
