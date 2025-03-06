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
    
    @State private var savePreset = true
    @State private var scheduleEnabled = false
    @State private var isDurationPickerExpanded = false

    @FocusState private var isTextFieldFocused: Bool

    // For picker wheels
    let hours = Array(0...23)
    let minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    CardSection {
                        // Save Preset Toggle
                        HStack {
                            Text("Save Preset")
                                .font(.body)

                            Spacer()

                            Toggle("", isOn: $savePreset.animation())
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .labelsHidden()
                        }
                    }

                    Text("Toggle off for a single use preset")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)

                    // Name Field
                    if savePreset {
                        CardSection {
                            HStack {
                                Text("Name")
                                    .font(.body)

                                Spacer()

                                TextField("", text: $preset.name, prompt: Text("Required").foregroundColor(.gray))
                                    .multilineTextAlignment(.trailing)
                                    .focused($isTextFieldFocused)
                            }
                            .padding(.vertical, 6)
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
                            .padding(.vertical, 6)
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
                    if savePreset {
                        CardSection {
                            HStack {
                                Text("Schedule")
                                    .font(.body)

                                Spacer()

                                Toggle("", isOn: $scheduleEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .green))
                                    .labelsHidden()
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .padding()

            VStack(spacing: 0) {
                Button("Continue") {
                    path.append(CreatePresetPage.summary)
                }
                .disabled(!allowSave)
                .buttonStyle(ActionButtonStyle(.primary))
                .padding()
            }
            .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))

        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Create a Preset")
        .edgesIgnoringSafeArea(.bottom)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    var allowSave: Bool {
        return (!savePreset && preset.duration != nil) || (savePreset && !preset.name.isEmpty && preset.duration != nil)
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
