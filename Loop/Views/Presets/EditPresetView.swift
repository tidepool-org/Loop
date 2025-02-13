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

struct CompactSection<Content: View, Header: View, Footer: View>: View {
    let header: Header?
    let footer: Footer?
    let content: Content

    // Initializer for custom view header
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header, @ViewBuilder footer: () -> Footer) {
        self.content = content()
        self.header = header()
        self.footer = footer()
    }

    // Initializer for string header
    init(_ headerText: String? = nil, @ViewBuilder content: () -> Content, footerText: String? = nil) where Header == Text, Footer == Text {
        self.content = content()
        self.header = headerText.map { Text($0) }
        self.footer = footerText.map { Text($0) }
    }

    // Initializer for no header
    init(@ViewBuilder content: () -> Content) where Header == Text, Footer == Text {
        self.content = content()
        self.header = nil
        self.footer = nil
    }

    var body: some View {
        Section {
            content
        } header: {
            if let header {
                header
                    .padding([.leading, .trailing], -10)
            }
        } footer: {
            if let footer {
                footer
            }
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
    }
}


struct EditPresetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.guidanceColors) private var guidanceColors
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference

    @State private var presetName: String
    @State private var preset: SelectablePreset

    private var originalPreset: SelectablePreset
    private var scheduledRange: ClosedRange<LoopQuantity>
    private var onSave: (SelectablePreset) throws -> Void

    @State private var showingPicker = false

    init(preset: SelectablePreset, scheduledRange: ClosedRange<LoopQuantity>, onSave: @escaping ((SelectablePreset) throws -> Void)) {
        self.preset = preset
        self.originalPreset = preset
        self.presetName = preset.name
        self.scheduledRange = scheduledRange
        self.onSave = onSave
    }

    func boundText(for bound: LoopQuantity) -> Text {
        let color = preset.guardrail.color(for: bound, guidanceColors: guidanceColors)
        let text = displayGlucosePreference.format(bound, includeUnit: false)
        switch preset.guardrail.classification(for: bound) {
        case .withinRecommendedRange:
            return Text(text)
                .foregroundColor(.accentColor)
                .font(.system(size: 34, weight: .bold))
        case .outsideRecommendedRange:
            return (
                Text(Image(systemName: "exclamationmark.triangle.fill"))
                    .font(.system(size: 23, weight: .regular))
                    .baselineOffset(3.0)
                    .foregroundColor(color) +
                Text(text)
                    .foregroundColor(color)
                    .font(.system(size: 34, weight: .bold))
                )
        }
    }

    func correctionRangeLabel(range: ClosedRange<LoopQuantity>) -> Text {
        boundText(for: (preset.correctionRange ?? scheduledRange).lowerBound) +
        Text("-").foregroundColor(.secondary)
            .font(.system(size: 34, weight: .light))
        +
        boundText(for: (preset.correctionRange ?? scheduledRange).upperBound) +
        Text(" ") +
        Text(displayGlucosePreference.unit.localizedShortUnitString)
            .font(.system(.body))
            .foregroundColor(.secondary)
            .baselineOffset(5)
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
                            .font(.system(size: 34, weight: .semibold))
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
                        .italic()
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
                    guardrail: preset.guardrail,
                    scheduledRange: scheduledRange
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

                CompactSection(
                    content: {
                        Button(action: {
                            showingPicker = true
                        }) {
                            HStack {
                                Text("Duration")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(preset.duration.localizedTitle)
                                    .foregroundColor(.secondary)
                                if preset.canAdjustDuration {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            }
                        }.disabled(!preset.canAdjustDuration)
                    },
                    footerText: preset.canAdjustDuration ? nil : "Duration and Name not configurable for this preset.")
            }
            .listSectionSpacing(16)
        }
        .sheet(isPresented: $showingPicker) {
            DurationPickerView(durationType: $preset.duration)
            .presentationDetents([.height(300)])
        }
        .onChange(of: preset, {
            do {
                try onSave(preset)
            } catch {
                print(error)
            }
        })
    }

    var presetTitle: some View {
        HStack(spacing: 6) {
            switch preset.icon {
            case .emoji(let emoji):
                Text(emoji)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.primary)
            case .image(let name, let iconColor):
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(iconColor)
                    .frame(width: UIFontMetrics.default.scaledValue(for: 34), height: UIFontMetrics.default.scaledValue(for: 34))
            }

            Text(presetName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

}
