//
//  EditPresetView.swift
//  Loop
//
//  Created by Pete Schwamb on 12/09/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftUI
import LoopKitUI
import LoopAlgorithm
import LoopCore

struct EditPresetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorPalette) private var colorPalette
    @Environment(\.settingsManager) private var settingsManager
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference

    enum Destination {
        case editCorrectionRange
        case editInsulinNeeds
    }

    @State private var preset: SelectablePreset
    @State private var navigationPath = NavigationPath()
    @State private var isDurationPickerExpanded = false
    @State private var showingDayPicker: Bool = false
    @State private var isConfirmingDelete = false

    @FocusState private var isTextFieldFocused: Bool

    private var originalPreset: SelectablePreset
    private var scheduledRange: ClosedRange<LoopQuantity>
    private var onSave: (SelectablePreset) throws -> Void
    private var onDelete: (SelectablePreset) throws -> Void

    private var activityPresetIsModified: Bool? {
        guard case let .activity(activityPreset) = preset else { return nil }
        
        return activityPreset.isModifiedFromDefault
    }

    init(
        preset: SelectablePreset,
        scheduledRange: ClosedRange<LoopQuantity>,
        onSave: @escaping ((SelectablePreset) throws -> Void),
        onDelete: @escaping ((SelectablePreset) throws -> Void)
    ) {
        self.preset = preset
        self.originalPreset = preset
        self.scheduledRange = scheduledRange
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var sensitivitySection: some View {
        Button {
            if preset.canAdjustSensitivity {
                navigationPath.append(Destination.editInsulinNeeds)
            }
        } label: {
            CardSection("Temporary Settings Adjustments") {
                InsulinNeedsAdjustmentPreview(
                    insulinPercentage: preset.insulinNeedsScaleFactor * 100,
                    guardrail: Guardrail.presetInsulinNeeds,
                    showDisclosure: preset.canAdjustSensitivity
                )
                if (!preset.canAdjustSensitivity) {
                    (Text(Image(systemName: "info.circle")) + Text(" Overall insulin cannot be adjusted for this preset"))
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .italic()
                        .padding(.top, 4)
                }
            }
            .foregroundColor(.primary)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollViewReader { scrollViewProxy in
                CardSectionScrollView {
                    presetTitle

                    sensitivitySection

                    CardSection {
                        Button {
                            navigationPath.append(Destination.editCorrectionRange)
                        } label: {
                            CorrectionRangePreview(
                                range: preset.correctionRange,
                                guardrail: settingsManager.correctionRangeGuardrailForPreset(preset),
                                scheduledRange: scheduledRange,
                                veryHighInsulinNeeds: preset.veryHighInsulinNeeds,
                                showDisclosure: true
                            )
                        }.accessibilityIdentifier("button_CorrectionRange")
                    }
                    
                    if let activityPresetIsModified {
                        Group {
                            if activityPresetIsModified {
                                Button {
                                    if case let .activity(activityPreset) = preset {
                                        withAnimation {
                                            preset = .activity(ActivityPreset(activityType: activityPreset.activityType, preset: activityPreset.activityType.defaultPreset(duration: activityPreset.preset.duration)))
                                        }
                                    }
                                } label: {
                                    Group {
                                        Text(Image(systemName: "arrow.uturn.backward")) + Text(" ") + Text("Revert to recommended values")
                                    }
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(ActionButtonStyle(.secondary))
                            } else {
                                Group {
                                    Text(Image(systemName: "checkmark.seal.fill")) + Text(" ") + Text("Recommended starting values")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    CardSection("Preset Details") {
                        HStack {
                            Text("Name")
                            Spacer()
                            if preset.canChangeName {
                                TextField("", text: $preset.name, prompt: Text("Required"))
                                    .multilineTextAlignment(.trailing)
                                    .focused($isTextFieldFocused)
                                    .foregroundColor(.secondary)
                            } else {
                                HStack(spacing: 4) {
                                    if case let .activity(activityPreset) = preset {
                                        Text(Image(systemName: activityPreset.activityType.symbol.value))
                                    }
                                    
                                    Text(preset.name)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Duration Section
                    if preset.canAdjustDuration {
                        CardSection {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Duration")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Group {
                                        Text(preset.duration.localizedTitle)
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isTextFieldFocused = false
                                    withAnimation {
                                        isDurationPickerExpanded.toggle()
                                        Task {
                                            if isDurationPickerExpanded {
                                                try? await Task.sleep(nanoseconds: 200_000_000) // ~0.2s delay
                                                withAnimation {
                                                    scrollViewProxy.scrollTo("durationPicker", anchor: .bottom)
                                                }
                                            }
                                        }
                                    }
                                }

                                if isDurationPickerExpanded {
                                    DurationPickerView(
                                        durationType: $preset.duration,
                                        allowIndefinite: preset.allowsIndefiniteDuration
                                    )
                                    .id("durationPicker") // Assign an ID for scrolling
                                }
                            }
                        }
                        .id("durationSection") // Optional: ID for the entire duration section
                    }

                    // Schedule Toggle
                    if preset.allowsScheduling {
                        CardSection {
                            HStack {
                                Text("Schedule")
                                    .font(.body)

                                Spacer()

                                Toggle("", isOn: Binding(get: {
                                    return preset.isScheduled
                                }, set: { newValue in
                                    withAnimation {
                                        if newValue {
                                            preset.scheduleStartDate = Date().addingTimeInterval(.hours(1))
                                            Task {
                                                try? await Task.sleep(nanoseconds: 200_000_000) // ~0.2s delay
                                                withAnimation {
                                                    scrollViewProxy.scrollTo("repeatOption", anchor: .bottom)
                                                }
                                            }
                                        } else {
                                            preset.scheduleStartDate = nil
                                            preset.repeatOptions = .none
                                        }
                                    }
                                }))
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .labelsHidden()
                                .padding(.vertical, -4)
                            }

                            if preset.isScheduled {
                                Divider()
                                HStack {
                                    if preset.repeatOptions != .none {
                                        Text("Next Date")
                                    } else {
                                        Text("Start Date")
                                    }
                                    Spacer()
                                    DatePicker(
                                        "",
                                        selection: Binding(get: {
                                            preset.nextScheduledStartAfter(Date()) ?? Date()
                                        }, set: { newValue in
                                            preset.scheduleStartDate = newValue
                                        }),
                                        in: Date().addingTimeInterval(.minutes(1))...,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                }
                                Divider()
                                    .padding(.top, -4)
                                HStack {
                                    Text("Repeat")
                                    Spacer()
                                    Picker("Repeat", selection: Binding<RepeatOption>(
                                        get: { preset.repeatOptions == .none ? .never : .weekly },
                                        set: { newValue in
                                            if newValue == .never {
                                                preset.repeatOptions = .none
                                            } else {
                                                Task {
                                                    if let requiredRepeatOption {
                                                        preset.repeatOptions = requiredRepeatOption
                                                    }
                                                    try? await Task.sleep(nanoseconds: 200_000_000) // ~0.2s delay
                                                    withAnimation {
                                                        scrollViewProxy.scrollTo("selectedDays", anchor: .bottom)
                                                    }
                                                }
                                            }
                                        }
                                    ).animation()) {
                                        ForEach(RepeatOption.allCases, id: \.self) { option in
                                            Text(String(describing: option))
                                        }
                                    }
                                    .tint(.secondary)
                                    .pickerStyle(MenuPickerStyle())
                                    .padding(.trailing, -8)
                                }
                                .id("repeatOption") // Assign an ID for scrolling


                                if preset.repeatOptions != .none {
                                    Divider()
                                        .padding(.top, -4)
                                    HStack {
                                        Text("Selected days")
                                            .foregroundColor(.primary)
                                        HStack {
                                            Spacer()
                                            RepeatOptionView(repeatOptions: preset.repeatOptions)
                                                .padding(.vertical, 6)
                                                .onTapGesture {
                                                    withAnimation {
                                                        showingDayPicker = true
                                                    }
                                                }
                                        }
                                        .popover(isPresented: $showingDayPicker, arrowEdge: .bottom) {
                                            DayPickerPopup(selectedDays: Binding(
                                                get: {
                                                    preset.repeatOptions
                                                }, set: { newValue in
                                                    preset.repeatOptions = newValue.union(requiredRepeatOption ?? .none)
                                                }))
                                            .cornerRadius(12)
                                            .presentationCompactAdaptation(.popover)
                                        }
                                    }
                                    .id("selectedDays") // Assign an ID for scrolling
                                }
                            }
                        }
                    }

                    if preset.canBeDeleted {
                        Button("Delete Preset") {
                            isConfirmingDelete = true
                        }
                        .buttonStyle(ActionButtonStyle(.destructive))
                        .padding(.top)
                    }
                }
                .animation(.easeInOut, value: preset.duration)
            }
            .navigationBarItems(trailing: dismissButton)
            .navigationDestination(for: Destination.self) { dest in
                switch dest {
                case .editInsulinNeeds:
                    ExistingPresetInsulinNeedsEdit(
                        insulinScaleFactor: $preset.insulinNeedsScaleFactor,
                        presetUsesScheduledRange: preset.correctionRange == nil
                    )
                case .editCorrectionRange:
                    ExistingPresetRangeEdit(
                        range: $preset.correctionRange,
                        guardrail: settingsManager.correctionRangeGuardrailForPreset(preset),
                        scheduledRange: scheduledRange,
                        allowsScheduledRange: preset.canAdjustSensitivity,
                        isPreMeal: preset.isPreMeal,
                        presetAdjustsInsulinNeeds: preset.insulinNeedsScaleFactor != 1,
                        requiresHighInsulinNeedsMitigation: preset.veryHighInsulinNeeds
                    )
                }
            }

            .onChange(of: preset) {
                do {
                    try onSave(preset)
                } catch {
                    print(error)
                }
            }
            .alert(isPresented: $isConfirmingDelete) {
                Alert(
                    title: Text("Delete “\(preset.name)”?"),
                    message: Text("Are you sure you want to delete this preset?"),
                    primaryButton: .default(Text("Go Back")),
                    secondaryButton: .destructive(Text("Yes, Delete").bold(), action: {
                        do {
                            try onDelete(preset)
                            dismiss()
                        } catch {
                            print(error)
                        }
                    })
                )
            }
        }
    }

    private var requiredRepeatOption: PresetScheduleRepeatOptions? {
        guard let startDate = preset.scheduleStartDate else { return nil }
        return .allCases[Calendar.current.component(.weekday, from: startDate) - 1]
    }

    private var dismissButton: some View {
        Button("Done") {
            dismiss()
        }.bold()
    }

    var presetTitle: some View {
        HStack(spacing: 6) {
            if let icon = preset.icon, !icon.isEmpty {
                PresetSymbolView(icon, iconSize: 34)
            }

            Text(preset.name)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}
