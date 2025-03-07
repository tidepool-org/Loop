//
//  CreatePresetReviewView.swift
//  Loop
//
//  Created by Pete Schwamb on 3/6/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import SwiftUI
import LoopUI

struct CreatePresetReviewView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var preset: NewCustomPreset
    @Binding var path: NavigationPath

    @State private var scheduleEnabled = false
    @State private var isDurationPickerExpanded = false

    @FocusState private var isTextFieldFocused: Bool

    // For picker wheels
    let hours = Array(0...23)
    let minutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]

    var body: some View {
        CardSectionScrollView {
            VStack(alignment: .leading) {
                Text("New Preset")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Review Settings")
                    .font(.system(size: 17, weight: .semibold))
                Text("Review your preset settings below. To make any changes, tap on the row you’d like to edit. You can edit these settings at any time.")
                    .font(.system(size: 13))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor)
                .frame(maxWidth: .infinity))
            .padding(.top, 10)
            .clipped()

            // Name Field
            if preset.savePreset {
                CardSection("Temporary Settings Adjustments") {
                    HStack {
                        Text("Name")
                            .font(.body)

                        Spacer()

                        TextField("", text: $preset.name, prompt: Text("Required").foregroundColor(.gray))
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
        .edgesIgnoringSafeArea([.top])
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

// Preview Provider
struct CreatePresetReviewView_Previews: PreviewProvider {
    @State static var preset: NewCustomPreset = .init()
    @State static var path: NavigationPath = .init()

    static var previews: some View {
        CreatePresetReviewView(preset: $preset, path: $path)
    }
}
