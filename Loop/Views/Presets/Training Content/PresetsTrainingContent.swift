//
//  PresetsTrainingContent.swift
//  Loop
//
//  Created by Cameron Ingham on 8/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import LoopKitUI
import SwiftUI

extension PresetsTraining {
    enum CTA {
        case start
        case `continue`
        case closeOrContinue(_ to: String, chapter: Chapter)
    }
}

protocol PresetsTrainingContent {
    associatedtype B: View
    func content(appName: String, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette) -> B
    var cta: PresetsTraining.CTA? { get }
}

extension PresetsTraining.Step: PresetsTrainingContent {
    @ViewBuilder
    func content(appName: String, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette) -> some View {
        switch self {
        case .entryPoint:
            if let image = Image("PresetsTrainingEntryHero") {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }
            
            EstimatedReadTime(.minutes(3))
            
            Text("Presets allow you temporarily adjust your settings for events like meals, exercise, illness, or hormonal changes that may affect your diabetes management.")
            
            VStack(alignment: .leading) {
                Text("We'll walk you through the following:")
                
                BulletedListView {
                    Text("How Presets Work")
                    Text("Using pre-configured presets")
                    Text("Timing your presets for exercise")
                    Text("Safe Glucose Ranges for Exercise")
                }
                .padding(.leading, 8)
            }
            
        case .tier1(let tier1Chapter):
            switch tier1Chapter {
            case .introduction(let introduction):
                switch introduction {
                case .introduction:
                    if let image = Image("PresetsTrainingEntryHero") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    EstimatedReadTime(.minutes(3))
                    
                    VStack(alignment: .leading) {
                        Text("With a preset, you can:")
                        
                        BulletedListView {
                            Text("Adjust your overall insulin needs")
                            Text("Set an adjusted correction range")
                            Text("Choose a duration")
                            Text("Schedule a preset in advance")
                        }
                        .padding(.leading, 8)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Adjusting Overall Insulin Needs")
                            .font(.title2.bold())
                        
                        Text("Overall insulin should be adjusted when your body needs more or less insulin than normal.")
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Adjusting Correction Range")
                            .font(.title2.bold())
                        
                        Text("The correction range is a safety setting. Adjusting it can help reduce the risk of low glucose if you expect unusual changes.")
                    }
                    
                case .exercisingWithLoop:
                    if let image = Image("PresetsTrainingExercisingWithLoopHero") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Text("Exercise and physical activity are common uses for presets.")
                    
                    Text("\(appName) has a few preset options designed to help with your insulin management. We designed these for various types of physical activities.")
                    
                    ActivityPreset.bulletList(full: true)
                        .padding(.leading, 8)
                    
                    Text("These presets are a starting point to help manage your glucose. You may need to work with your healthcare provider to edit them to meet your personal diabetes needs.")
                    
                case .timingYourPresets:
                    Text("\(appName) suggests starting a preset for exercise at least 1 hour ahead of time. Keep it on until you finish your activity.")
                    
                    Text("If you forget to turn on a preset, turn it on as soon as you remember and keep it on until the activity ends.")
                    
                    InsetContent {
                        Timeline {
                            TimelineStep(
                                symbol: Image(systemName: "clock"),
                                title: Text("1 Hour Before"),
                                subtitle: Text("Enable your preset")
                            )
                        
                            TimelineStep(
                                symbol: Image(systemName: "figure.run"),
                                title:  Text("During Activity"),
                                subtitle:  Text("Keep preset on throughout your exercise")
                            )
                        
                            TimelineStep(
                                symbol: Image(systemName: "checkmark"),
                                symbolInset: 2,
                                title:  Text("Activity Ends"),
                                subtitle:  Text("Turn off preset when you finish exercising")
                            )
                        }
                    }
                    
                    Text("You can plan ahead and schedule presets to start at a certain date and time. The app will send you a reminder and ask if you'd like to start the preset.")
                    
                case .safeGlucoseRanges:
                    Text("Before starting exercise, make sure to check your glucose.")
                    
                    Text("Aim for your glucose to be between \(displayGlucosePreference.format(LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), includeUnit: false)) and \(displayGlucosePreference.format(LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 180), includeUnit: true)) before exercising. Based on current research, this can help prevent high and low levels during or after your workout.")
                    
                    InsetContent {
                        Text("Safe Starting Glucose Range")
                            .bold()
                        
                        Group {
                            Text("\(displayGlucosePreference.format(LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), includeUnit: false))-\(displayGlucosePreference.format(LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 180), includeUnit: false)) ")
                                .font(.system(size: UIFontMetrics.default.scaledValue(for: 32)).weight(.heavy))
                            + Text(displayGlucosePreference.unit.localizedShortUnitString)
                        }
                        .foregroundStyle(colorPalette.carbTintColor)
                        
                        Text("\(Image(systemName: "exclamationmark.circle")) Consider a small snack to prevent lows")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    Callout(.caution, title: Text("Starting a preset, especially one decreasing insulin, when your glucose is above \(displayGlucosePreference.format(LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 180), includeUnit: true)) may reduce its effectiveness and impact your results."))
                        .padding(.horizontal, -16)
                    
                    Text("Always check your glucose before, during, and after any activity to ensure safe and optimal outcomes.")
                    
                case .performanceHistory:
                    if let image = Image("PresetsTrainingPerformanceHistoryHero") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Text("Performance History gives you a clear picture of how each preset helped manage your glucose.")
                    
                    Text("You can quickly review a summary of key data during the preset and for the six hours that follow to understand the full impact of the preset’s settings.")
                    
                    Text("To get started, tap Presets, then Performance History, and select the preset you want to review.")
                    
                    Text("Performance history is available for up to seven days.")
                    
                case .complete:
                    Text("You can now use the following presets:")
                    
                    ActivityPreset.bulletList(full: false)
                    
                    Text("Complete Part 2 to enable preset editing and creation.")
                }
            }
        }
    }
    
    var cta: PresetsTraining.CTA? {
        switch self {
        case .entryPoint: .start
        case .tier1(let tier1Chapter):
            switch tier1Chapter {
            case .introduction(let introduction):
                switch introduction {
                case .introduction: .continue
                case .exercisingWithLoop: .continue
                case .timingYourPresets: .continue
                case .safeGlucoseRanges: .continue
                case .performanceHistory: .continue
                case .complete: .closeOrContinue("Step 2", chapter: .introduction)
                }
            }
        }
    }
}

extension PresetsTraining.Chapter: PresetsTrainingContent {
    @ViewBuilder
    func content(appName: String, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette) -> some View {
        firstStep.content(appName: appName, displayGlucosePreference: displayGlucosePreference, colorPalette: colorPalette)
    }
    
    var cta: PresetsTraining.CTA? {
        firstStep.cta
    }
}

extension ActivityPreset.ActivityType {
    func bulletItem(full: Bool) -> Text {
        if full {
            return Text(Image(systemName: systemImageName))
                .fontDesign(.monospaced)
            + Text(" \(name) · ")
                .fontWeight(.semibold)
            + Text("\(defaultInsulinNeedsScaleFactor.formatted(.percent)) of insulin")
        } else {
            return Text(Image(systemName: systemImageName))
                .fontDesign(.monospaced)
            + Text(" \(name)")
                .fontWeight(.semibold)
        }
    }
}

extension ActivityPreset {
    @ViewBuilder
    static func bulletList(full: Bool) -> some View {
        BulletedListView {
            ActivityPreset.ActivityType.jogging.bulletItem(full: full)
            ActivityPreset.ActivityType.walking.bulletItem(full: full)
            ActivityPreset.ActivityType.biking.bulletItem(full: full)
            ActivityPreset.ActivityType.strengthTraining.bulletItem(full: full)
        }
    }
}
