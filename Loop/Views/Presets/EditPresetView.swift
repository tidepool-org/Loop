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
    @State private var navigateToCorrectionRangeEditor = false

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
            .baselineOffset(12)
    }

    var sensitivitySection: some View {
        CardSection("Temporary Settings Adjustments") {
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

    private var correctionRangeCrossedThresholds: [SafetyClassification.Threshold] {
        guard let range = preset.correctionRange else { return [] }

        let guardrail = preset.guardrail
        let thresholds: [SafetyClassification.Threshold] = [range.lowerBound, range.upperBound].compactMap { bound in
            switch guardrail.classification(for: bound) {
            case .withinRecommendedRange:
                return nil
            case .outsideRecommendedRange(let threshold):
                return threshold
            }
        }

        return thresholds
    }

    private var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.correctionRangeCrossedThresholds
        let severity = crossedThresholds.map { $0.severity }.max()

        return Group {
            if let severity, !crossedThresholds.isEmpty {
                let color: Color = severity > .default ? guidanceColors.critical : guidanceColors.warning
                HStack(alignment: .top, spacing: 12) {
                    Text(Image(systemName: "exclamationmark.triangle.fill"))
                        .foregroundColor(color)
                    Text(SafetyClassification.captionForCrossedThresholds(crossedThresholds, isRange: true));
                }
                .padding(12)
                .background(color.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }


    var correctionSection: some View {
        CardSection {
            Button {
                navigateToCorrectionRangeEditor = true;
            } label: {
                VStack(alignment: .center, spacing: 12) {
                    HStack {
                        Text("Correction Range")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }.padding(.bottom, 10)
                    VStack(spacing: 4) {
                        if let range = preset.correctionRange {
                            correctionRangeLabel(range: range)
                            Text("Adjusted Range")
                        } else {
                            correctionRangeLabel(range: scheduledRange)
                            Text("Scheduled Range")
                        }
                    }
                    guardrailWarningIfNecessary
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 5)
                        .padding(.horizontal, 2)
                }
                .foregroundColor(.primary)
            }
        }
    }


    var body: some View {
        CardSectionScrollView {
            presetTitle

            sensitivitySection

            correctionSection

            CardSection("Preset Details") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(presetName)
                        .foregroundColor(.secondary)
                }
            }

            CardSection(
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
                footerText: preset.canAdjustDuration ? nil : "Duration and Name not configurable for this preset."
            )
        }
        .sheet(isPresented: $showingPicker) {
            VStack(alignment: .center, spacing: 24) {
                HStack {
                    Text("Duration")
                        .font(.system(size: 17, weight: .regular))
                    Spacer()
                    Text("Required")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.gray)
                }
                DurationPickerView(durationType: $preset.duration)
                    .presentationDetents([.height(300)])
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
        }
        .navigationDestination(isPresented: $navigateToCorrectionRangeEditor) {
            ExistingPresetRangeEdit(
                range: $preset.correctionRange,
                guardrail: preset.guardrail,
                scheduledRange: scheduledRange,
                allowsScheduledRange: preset.canAdjustSensitivity
            )
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
