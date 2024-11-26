//
//  PresetsView.swift
//  Loop
//
//  Created by Cameron Ingham on 10/23/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI

enum PresetSortOption: String, CaseIterable {
    case name = "Name"
    case lastUsed = "Last Used"
    case dateCreated = "Date Created"
}

struct PresetsView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: PresetsViewModel

    @State private var editMode: EditMode = .inactive
    @State private var selectedSortOption: PresetSortOption = .name
    @State private var isAscending: Bool = true
    @State private var showingMenu: Bool = false

    var isDescending: Bool { !isAscending }

    init(viewModel: PresetsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var presetsSorted: [SelectablePreset] {
        viewModel.allPresets.sorted(by: {
            switch (selectedSortOption) {
            case .name:
                return ($0.name.lowercased() < $1.name.lowercased()) != isDescending
            default: return true
            }
        })
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

                            sortMenu
                            Button(action: {}) {
                                Image(systemName: "plus")
                            }.disabled(!viewModel.hasCompletedTraining)
                        }

                        LazyVStack(spacing: 12) {
                            ForEach(presetsSorted) { preset in
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

    private var sortMenu: some View {
        Button("Sort") {
            showingMenu.toggle()
        }
        .popover(isPresented: $showingMenu) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sort By")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        isAscending.toggle()
                    }) {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                Divider()

                ForEach(PresetSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        selectedSortOption = option
                        showingMenu = false
                    }) {
                        HStack {
                            if selectedSortOption == option {
                                Image(systemName: "checkmark")
                            } else {
                                Image(systemName: "checkmark")
                                    .hidden()
                            }
                            Text(option.rawValue)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, option == PresetSortOption.allCases.last ? 12 : 0)
                    if option != PresetSortOption.allCases.last {
                        Divider()
                    }
                }
            }
            .frame(width: 200)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var dismissButton: some View {
        Button("Done") {
            dismiss()
        }.bold()
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

