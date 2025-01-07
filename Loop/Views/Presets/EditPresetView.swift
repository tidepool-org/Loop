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

struct CompactSection<Content: View, Header: View>: View {
    let header: Header?
    let content: Content

    // Initializer for custom view header
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
        self.content = content()
        self.header = header()
    }

    // Initializer for string header
    init(_ headerText: String?, @ViewBuilder content: () -> Content) where Header == Text {
        self.content = content()
        self.header = headerText.map { Text($0) }
    }

    // Initializer for no header
    init(@ViewBuilder content: () -> Content) where Header == Text {
        self.content = content()
        self.header = nil
    }

    var body: some View {
        Section {
            content
        } header: {
            if let header {
                header
                    .padding([.leading, .trailing], -10)
            }
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
    }
}


struct EditPresetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference

    @State private var duration: TimeInterval = 3600 // 1 hour in seconds
    @State private var presetName: String
    @State private var preset: SelectablePreset

    private var originalPreset: SelectablePreset
    private var scheduledRange: ClosedRange<LoopQuantity>

    init(preset: SelectablePreset, scheduledRange: ClosedRange<LoopQuantity>) {
        self.preset = preset
        self.originalPreset = preset
        self.presetName = preset.name
        self.scheduledRange = scheduledRange
    }

    func correctionRangeLabel(range: ClosedRange<LoopQuantity>) -> Text {
        let rangeStr = displayGlucosePreference.format(lowerQuantity: range.lowerBound, higherQuantity: range.upperBound, includeUnit: false)

        return Text(rangeStr)
            .font(.system(size: 32, weight: .semibold))
            .foregroundColor(.accentColor) +
        Text(" ") +
        Text(displayGlucosePreference.unit.localizedShortUnitString)
            .font(.system(.body))
            .foregroundColor(.secondary)
    }

    var sensitivitySection: some View {
        CompactSection("Temporary Settings Adjustments") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Overall Insulin")
                    .font(.system(.title3, weight: .semibold))

                HStack {
                    Spacer()
                    VStack(alignment: .center) {
                        Text("\(Int((1.0 / (preset.insulinSensitivityMultiplier ?? 1)) * 100))%")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Text("of scheduled")
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }

                if (!preset.canAdjustSensitivity) {
                    (Text(Image(systemName: "info.circle")) + Text(" Overall insulin cannot be adjusted for this preset"))
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .padding(.top, 4)
                }
            }
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        }
    }

    var correctionSection: some View {
        CompactSection {
            NavigationLink {
                EditPresetRangeView(
                    range: $preset.correctionRange,
                    guardrail: preset.guardrail
                )
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Correction Range")
                        .font(.system(.title3, weight: .semibold))
                    HStack {
                        Spacer()
                        VStack(alignment: .center) {
                            if let range = preset.correctionRange {
                                correctionRangeLabel(range: range)
                                Text("Adjusted Range")
                                    .foregroundColor(.primary)
                            } else {
                                correctionRangeLabel(range: scheduledRange)
                                Text("Scheduled Range")
                                    .foregroundColor(.primary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {} header: {
                    presetTitle
                }
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))
                .textCase(nil)

                sensitivitySection

                correctionSection

                CompactSection("PRESET DETAILS") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(presetName)
                            .foregroundColor(.secondary)
                    }
                }

                CompactSection() {
                    NavigationLink {
                        Text("Duration Detail View")
                    } label: {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(preset.duration.localizedTitle)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                CompactSection {} header: {
                    Button("Save Preset") {
                        dismiss()
                    }
                    .disabled(preset == originalPreset)
                    .buttonStyle(ActionButtonStyle(.primary))
                    .textCase(nil)
                }
            }
            .listSectionSpacing(16)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            trailing: Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.blue)
        )
    }

    var presetTitle: some View {
        HStack(spacing: 6) {
            switch preset.icon {
            case .emoji(let emoji):
                Text(emoji)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.primary)
            case .image(let name, let iconColor):
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(iconColor)
                    .frame(width: UIFontMetrics.default.scaledValue(for: 48), height: UIFontMetrics.default.scaledValue(for: 48))
            }

            Text(presetName)
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

}
