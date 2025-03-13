//
//  CreatePresetNameAndScheduledEdit.swift
//  Loop
//
//  Created by Pete Schwamb on 3/5/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


import LoopKitUI
import SwiftUI

enum RepeatOption: CaseIterable {
    case never
    case weekly
}

extension RepeatOption: CustomStringConvertible {
    var description: String {
        switch self {
        case .never:
            NSLocalizedString(
                "Never",
                comment: "Repeat option never for a preset schedule"
            )
        case .weekly:
            NSLocalizedString(
                "Weekly",
                comment: "Repeat option weekly for a preset schedule"
            )
        }
    }
}

struct CreatePresetNameAndScheduledEdit: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var preset: NewCustomPreset
    @Binding var path: NavigationPath
    
    @State private var isDurationPickerExpanded = false

    @FocusState private var isTextFieldFocused: Bool

    @State private var selectedRepeatOption: RepeatOption = .never
    @State private var showingDayPicker: Bool = false

    var body: some View {
        CardSectionScrollView {
            CardSection {
                // Save Preset Toggle
                HStack {
                    Text("Save Preset")
                        .font(.body)

                    Spacer()

                    Toggle("", isOn: $preset.savePreset.animation())
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .labelsHidden()
                        .padding(.vertical, -6)
                }
            }

            Text("Toggle off for a single use preset")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)

            // Name Field
            if preset.savePreset {
                CardSection {
                    HStack {
                        Text("Name")
                            .font(.body)

                        Spacer()

                        TextField("", text: $preset.name, prompt: Text("Required"))
                            .multilineTextAlignment(.trailing)
                            .focused($isTextFieldFocused)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Duration Section
            CardSection {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Duration")
                            .foregroundColor(.primary)
                        Spacer()
                        Group {
                            if let duration = preset.duration {
                                Text(duration.localizedTitle)
                                Image(systemName: "chevron.right")
                            } else {
                                Text("Required")
                                    .foregroundStyle(.placeholder)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isTextFieldFocused = false
                        withAnimation() {
                            isDurationPickerExpanded.toggle()
                        }
                    }

                    if isDurationPickerExpanded {
                        DurationPickerView(
                            durationType: Binding(
                                get: {
                                    return preset.duration ?? .duration(0)
                                },
                                set: { duration in
                                    preset.duration = duration
                                }
                            )
                        )
                    }
                }
            }

            // Schedule Toggle
            if preset.savePreset {
                CardSection {
                    HStack {
                        Text("Schedule")
                            .font(.body)

                        Spacer()

                        Toggle("", isOn: Binding(get: {
                            return preset.startDate != nil
                        }, set: { newValue in
                            if newValue {
                                preset.startDate = Date()
                            } else {
                                preset.startDate = nil
                            }
                        }))
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .labelsHidden()
                        .padding(.vertical, -4)
                    }

                    if preset.startDate != nil {
                        Divider()
                        HStack {
                            if selectedRepeatOption == .never {
                                Text("Date")
                            } else {
                                Text("Start Date")
                            }
                            Spacer()
                            DatePicker(
                                "",
                                selection: Binding(get: {
                                    preset.startDate ?? Date()
                                }, set: { newValue in
                                    preset.startDate = newValue
                                }),
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                        Divider()
                            .padding(.top, -4)
                        HStack {
                            Text("Repeat")
                            Spacer()
                            Picker("Repeat", selection: $selectedRepeatOption) {
                                ForEach(RepeatOption.allCases, id: \.self) { option in
                                    Text(String(describing: option))
                                }
                            }
                            .tint(.secondary)
                            .pickerStyle(MenuPickerStyle())
                            .padding(.trailing, -8)
                        }

                        if selectedRepeatOption == .weekly {
                            Divider()
                                .padding(.top, -4)
                            HStack {
                                Button(action: {
                                    showingDayPicker = true
                                }) {
                                    HStack {
                                        Text("Selected days")
                                            .foregroundColor(.primary)
                                        Spacer()
                                        RepeatOptionView(repeatOptions: preset.repeatOptions ?? .none)
                                    }
                                    .padding(.vertical, 6)
                                }
                                .popover(isPresented: $showingDayPicker) {
                                    DayPickerPopup(selectedDays: Binding(
                                    get: {
                                        preset.repeatOptions ?? .none
                                    }, set: { newValue in
                                        preset.repeatOptions = newValue.union(requiredRepeatOption ?? .none)
                                    }))
                                    .cornerRadius(12)
                                    .presentationCompactAdaptation(.popover)
                                }
                            }

                        }
                    }
                }
                if preset.repeatOptions != nil {
                    Text(preset.scheduleDescription())
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                }
            }
        } actionArea: {
            Button("Continue") {
                path.append(CreatePresetPage.summary)
            }
            .disabled(!allowSave)
            .buttonStyle(ActionButtonStyle(.primary))
            .padding()
        }
        .onChange(of: selectedRepeatOption, { oldValue, newValue in
            if newValue == .weekly {
                assignRepeatDays()
            }
        })
        .onChange(of: preset.startDate, { oldValue, newValue in
            if newValue != nil {
                assignRepeatDays()
            }
        })

        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Create a Preset")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private var requiredRepeatOption: PresetScheduleRepeatOptions? {
        guard let startDate = preset.startDate else { return nil }
        guard selectedRepeatOption == .weekly else { return nil }
        return .allCases[Calendar.current.component(.weekday, from: startDate) - 1]
    }

    func assignRepeatDays() {
        guard let requiredRepeatOption else {
            return
        }
        preset.repeatOptions = requiredRepeatOption
    }

    var allowSave: Bool {
        return (!preset.savePreset && preset.duration != nil) || (preset.savePreset && !preset.name.isEmpty && preset.duration != nil)
    }
}

// Optional: Extension for expanded row when Duration is tapped
struct DurationRowView: View {
    @Binding var untilTurnOff: Bool
    @Binding var selectedHour: Int
    @Binding var selectedMinute: Int

    let hours = Array(0...23)
    let minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                Picker("Hour", selection: $selectedHour) {
                    ForEach(hours, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: UIScreen.main.bounds.width / 2)
                .clipped()

                Text("hour")
                    .foregroundColor(.gray)
                    .padding(.trailing, 20)

                Picker("Minute", selection: $selectedMinute) {
                    ForEach(minutes, id: \.self) { minute in
                        Text("\(minute)").tag(minute)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: UIScreen.main.bounds.width / 2)
                .clipped()

                Text("min")
                    .foregroundColor(.gray)
            }
            .frame(height: 120)

            HStack {
                Text("Until I turn off")
                    .font(.body)

                Spacer()

                Toggle("", isOn: $untilTurnOff)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
        }
    }
}

struct RepeatOptionView: View {
    let repeatOptions: PresetScheduleRepeatOptions

    private var selectedDays: [PresetScheduleRepeatOptions] {
        PresetScheduleRepeatOptions.allCases.filter { repeatOptions.contains($0) }
    }

    private var isSingleDay: Bool {
        selectedDays.count == 1
    }

    var body: some View {
        if repeatOptions == .none {
            Text(repeatOptions.description)
                .tint(.secondary)
        } else if isSingleDay {
            Text(selectedDays[0].description)
                .foregroundColor(.secondary)
        } else {
            HStack(spacing: 4) {
                ForEach(PresetScheduleRepeatOptions.allCases, id: \.rawValue) { day in
                    Text(String(day.description.first!))
                        .font(.system(size: 12))
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(repeatOptions.contains(day) ? Color.blue : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(repeatOptions.contains(day) ? .white : .gray)
                }
            }
        }
    }
}

// Preview Provider
struct PresetCreationView_Previews: PreviewProvider {
    @State static var preset: NewCustomPreset = .init()
    @State static var path: NavigationPath = .init()

    static var previews: some View {
        CreatePresetNameAndScheduledEdit(preset: $preset, path: $path)
    }
}
