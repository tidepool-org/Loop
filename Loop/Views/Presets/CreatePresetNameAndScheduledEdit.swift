//
//  CreatePresetNameAndScheduledEdit.swift
//  Loop
//
//  Created by Pete Schwamb on 3/5/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


import LoopKitUI
import SwiftUI

struct CreatePresetNameAndScheduledEdit: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var preset: NewCustomPreset
    @Binding var path: NavigationPath
    
    @State private var scheduleEnabled = false
    @State private var isDurationPickerExpanded = false

    @FocusState private var isTextFieldFocused: Bool

    @State private var scheduleDate: Date = Date()
    @State private var repeatOption: PresetScheduleRepeatOption?

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
                .foregroundColor(.gray)
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
                        if let duration = preset.duration {
                            Text(duration.localizedTitle)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Required")
                                .foregroundColor(.secondary)
                        }
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

                        Toggle("", isOn: $scheduleEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .labelsHidden()
                            .padding(.vertical, -6)
                    }

                    if scheduleEnabled {
                        Divider()
                        HStack {
                            Text("Date")
                            Spacer()
                            DatePicker("", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                        }
                        Divider()
                        HStack {
                            Text("Repeat")
                            Spacer()
                            Picker("Repeat", selection: $repeatOption) {
                                ForEach(PresetScheduleRepeatOption.allCases, id: \.self) { option in
                                    Text(String(describing: option))
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
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

// Preview Provider
struct PresetCreationView_Previews: PreviewProvider {
    @State static var preset: NewCustomPreset = .init()
    @State static var path: NavigationPath = .init()

    static var previews: some View {
        CreatePresetNameAndScheduledEdit(preset: $preset, path: $path)
    }
}
