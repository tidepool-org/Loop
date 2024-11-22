//
//  PresetsView.swift
//  Loop
//
//  Created by Cameron Ingham on 10/23/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct PresetsView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: PresetsViewModel

    @State private var editMode: EditMode = .inactive

    init(viewModel: PresetsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    if !viewModel.hasCompletedTraining {
                        PresetsTrainingCard(showTraining: $viewModel.showTraining)
                    }

                    // All Presets Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("All Presets")
                                .font(.title2.bold())
                            Spacer()
                            Button("Sort") {
                                // Sort action
                            }

                            Button(action: {}) {
                                Image(systemName: "plus")
                            }
                        }

                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.allPresets) { preset in
                                PresetCard(
                                    icon: preset.icon,
                                    presetName: preset.name,
                                    duration: preset.duration,
                                    insulinSensitivityMultiplier: preset.insulinSensitivityMultiplier,
                                    correctionRange: preset.correctionRange,
                                    guardrail: preset.guardrail
                                )
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                        }
                    }

                    // Support Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Support")
                            .font(.title2.bold())

                        NavigationLink(destination: EmptyView()) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.blue)
                                    .cornerRadius(8)

                                Text("Presets Performance History")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .navigationTitle(Text("Presets", comment: "Presets screen title"))
            .navigationBarItems(trailing: dismissButton)
        }

        .sheet(isPresented: $viewModel.showTraining) {
            PresetsTrainingView {
                viewModel.hasCompletedTraining = true
            }
        }
        .onAppear { // TODO: Remove this
            viewModel.hasCompletedTraining = false
        }
    }

    private var dismissButton: some View {
        Button("Done") {
            dismiss()
        }.bold()
    }

    private var listHeader: some View {
        HStack {
            Text("All Presets")
                .font(.title3)
                .fontWeight(.semibold)
                .textCase(nil)
                .foregroundColor(.primary)

            Spacer()

            editButton
        }
        .listRowInsets(EdgeInsets(top: 20, leading: 4, bottom: 10, trailing: 4))
    }

    private var editButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                editMode.toggle()
            }
        }) {
            Text(editMode.title)
                .textCase(nil)
        }
    }
}

