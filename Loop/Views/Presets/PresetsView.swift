//
//  PresetsView.swift
//  Loop
//
//  Created by Cameron Ingham on 10/23/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import LoopKitUI
import SwiftUI

enum PresetSortOption: Int, CaseIterable {
    case name
    case lastUsed
    case dateCreated

    var description: String {
        switch self {
        case .name:
            return NSLocalizedString("Name", comment: "Preset sorting option description for sorting by name")
        case .lastUsed:
            return NSLocalizedString("Last Used", comment: "Preset sorting option description for sorting by last used")
        case .dateCreated:
            return NSLocalizedString("Date Created", comment: "Preset sorting option description for sorting by date created")
        }
    }
}

struct PresetsView: View {
    
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.settingsManager) private var settingsManager
    @Environment(\.temporaryPresetsManager) private var temporaryPresetsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var editMode: EditMode = .inactive
    @State private var showingMenu: Bool = false
    @State private var showTraining: Bool = false
    @State private var presentCreateView: Bool = false
    @State private var editPresetPath: [String] = []
    @State private var pendingPreset: SelectablePreset?

    @AppStorage("presetsSortAscending") private var presetsSortAscending: Bool = true
    @AppStorage("presetsSortOrder") private var selectedSortOption: PresetSortOption = .name
    @AppStorage("hasCompletedPresetsTraining") private var hasCompletedTraining: Bool = false

    var isDescending: Bool { !presetsSortAscending }

    var presetsSorted: [SelectablePreset] {
        temporaryPresetsManager.selectablePresets
            .filter { $0.id != temporaryPresetsManager.activeOverride?.presetId }
            .sorted(by: {
            switch (selectedSortOption) {
            case .name:
                return ($0.name.lowercased() < $1.name.lowercased()) != isDescending
            case .dateCreated:
                return ($0.dateCreated > $1.dateCreated) != isDescending
            default:
                return ((temporaryPresetsManager.lastUsed(id: $0.id) ?? .distantPast) > (temporaryPresetsManager.lastUsed(id: $1.id) ?? .distantPast)) != isDescending
            }
        })
    }

    var scheduledRange: ClosedRange<LoopQuantity>? {
        settingsManager.therapySettings.glucoseTargetRangeSchedule?.quantityRange(at: Date())
    }

    var body: some View {
        NavigationStack(path: $editPresetPath) {
            ScrollView {
                VStack(spacing: 20) {
                    if !hasCompletedTraining {
                        PresetsTrainingCard(showTraining: $showTraining)
                    }

                    if let activePreset = temporaryPresetsManager.selectablePresets.first(where: { $0.id == temporaryPresetsManager.activeOverride?.presetId })
                    {
                        PresetCard(
                            activePreset,
                            guardrail: settingsManager.guardrailForPreset(activePreset),
                            expectedEndTime: temporaryPresetsManager.activeOverride?.expectedEndTime
                        )
                        .onTapGesture {
                            pendingPreset = activePreset
                        }
                    }

                    // All Presets Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("All Presets")
                                .font(.title2.bold())
                            Spacer()

                            Button("Sort") {
                                showingMenu.toggle()
                            }
                            .popover(isPresented: $showingMenu) {
                                sortMenu
                            }

                            Button(action: {
                                presentCreateView = true;
                            }) {
                                Image(systemName: "plus")
                            }
                            .disabled(!hasCompletedTraining)
                        }

                        LazyVStack(spacing: 12) {
                            ForEach(presetsSorted) { preset in
                                PresetCard(
                                    preset,
                                    guardrail: settingsManager.guardrailForPreset(preset)
                                )
                                .cornerRadius(12)
                                .onTapGesture {
                                    pendingPreset = preset
                                }
                            }
                        }
                    }

                    // Support Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Support")
                            .font(.title2.bold())

                        NavigationLink(destination: PresetsHistoryView()) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.presets)
                                    .cornerRadius(8)

                                Text("Presets Performance History")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(10)
                        .foregroundStyle(.primary)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.tertiarySystemBackground))
                            .stroke(Color(UIColor.secondarySystemBackground), lineWidth: 1)
                            .frame(maxWidth: .infinity))

                        if hasCompletedTraining {
                            Button {
                                showTraining = true
                            } label: {
                                HStack {
                                    Text("Review Presets Training")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(10)
                            .foregroundStyle(.primary)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.tertiarySystemBackground))
                                .stroke(Color(UIColor.secondarySystemBackground), lineWidth: 1)
                                .frame(maxWidth: .infinity))
                        }

                    }
                }
                .padding()
                .animation(.default, value: hasCompletedTraining)
                .animation(.default, value: temporaryPresetsManager.activeOverride)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .navigationTitle(Text("Presets", comment: "Presets screen title"))
            .navigationBarItems(trailing: dismissButton)
            .navigationDestination(for: String.self) { presetId in
                if let scheduledRange, let preset = temporaryPresetsManager.selectablePresets.first(where: { $0.id == presetId}) {
                    EditPresetView(
                        preset: preset,
                        scheduledRange: scheduledRange,
                        onSave: { preset in settingsManager.savePreset(preset) },
                        onDelete: { preset in settingsManager.deletePreset(preset) }
                    )
                }
            }
        }
        .sheet(item: $pendingPreset) { preset in
            PresetDetentView(preset: preset, didTapEdit: {
                editPresetPath.append(preset.id)
            })
        }
        .sheet(isPresented: $showTraining) {
            PresetsTrainingView {
                hasCompletedTraining = true
            }
        }
        .sheet(isPresented: $presentCreateView) {
            CreatePresetView()
        }
    }

    private var sortMenu: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sort By")
                    .font(.headline)
                Spacer()
                Button(action: {
                    presetsSortAscending.toggle()
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
                        Text(option.description)
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

extension PresetCard {
    init (_ preset: SelectablePreset, guardrail: Guardrail<LoopQuantity>, expectedEndTime: PresetExpectedEndTime? = nil) {
        self.init(
            icon: preset.icon,
            presetName: preset.name,
            duration: preset.duration,
            insulinMultiplier: preset.insulinNeedsScaleFactor,
            correctionRange: preset.correctionRange,
            guardrail: guardrail,
            expectedEndTime: expectedEndTime
        )
    }
}
