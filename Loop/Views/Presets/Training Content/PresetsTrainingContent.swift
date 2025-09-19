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
        case close
        case closeOrContinue(_ to: String, chapter: Chapter)
    }
}

protocol PresetsTrainingContent {
    associatedtype B: View
    func content(appName: String, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, dynamicTypeSize: DynamicTypeSize, next: @escaping () -> Void) -> B
    var cta: PresetsTraining.CTA? { get }
}

extension PresetsTraining.Step: PresetsTrainingContent {
    @ViewBuilder
    func content(appName: String, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, dynamicTypeSize: DynamicTypeSize, next: @escaping () -> Void) -> some View {
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
        case .tier2(let tier2Chapter):
            switch tier2Chapter {
            case .customizingPresets(let customizingPresets):
                switch customizingPresets {
                case .customizingPresets:
                    if let image = Image("PresetsTrainingCustomizingPresetsHero") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    EstimatedReadTime(.minutes(10))
                    
                    VStack(alignment: .leading) {
                        Text("Learn to tailor your settings! This training will teach you how to:")
                            .fixedSize(horizontal: false, vertical: true)
                        
                        BulletedListView {
                            Text("Configure each setting")
                            Text("Use Presets for when you are sick")
                            Text("Use Presets for Daily Activities")
                            Text("Use Presets for Exercise")
                        }
                        .padding(.leading, 8)
                    }
                        
                    Text("Complete this training to learn how to edit the pre-configured presets and adjust them to fit your needs, or create your own custom presets.")
                    
                case .overallInsulin:
                    if let image = Image("PresetsTrainingOverallInsulinHero") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("The \"Overall Insulin\" percentage controls total insulin delivery by adjusting your:")
                        
                        BulletedListView {
                            Text("Basal Rate")
                            Text("Carb Ratio")
                            Text("Insulin Sensitivity Factor (ISF)")
                        }
                        .padding(.leading, 8)
                    }
                    
                    Text("At 100%, \(appName) assumes your insulin needs are the same as usual.")
                    
                    Text("When deciding to adjust your overall insulin, **ask yourself, does my body need more or less than usual?**")
                    
                    Callout(.note) {
                        BulletedListView {
                            Text("A percentage **below 100%** tells the system you need **less** insulin")
                            
                            Text("A percentage **above 100%** tells the system you need **more** insulin")
                        }
                        .font(.footnote)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, -16)
                    
                case .correctionRange:
                    if let image = Image("PresetsTrainingCorrectionRangeHero") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Text("Correction range is a **safety setting**. Changing it can help lower your risk of going low if you expect unusual changes.")
                    
                    Text("Changing it can lower the chance of your glucose levels going too low if you expect unusual changes.")
                    
                    Text("Choose the glucose value (or values) you want \(appName) to target when changing how much basal insulin you get.")
                    
                    Text("You don’t need to change the correction range for every preset. But before you decide to change it, ask yourself: *Am I more likely to go high or low during this time?*")
                    
                    Callout(.note) {
                        Text("To help avoid lows, set a range **higher** than your typical correction range.")
                            .font(.footnote)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, -16)
                }
            case .illness(let illness):
                switch illness {
                case .commonUses:
                    Text("You can use presets for a variety of situations. Explore the uses below to learn tips for these common scenarios.")
                    
                    VStack(spacing: 16) {
                        CommonUseStep(
                            title: Text("Presets for Illness"),
                            readTime: .minutes(3),
                            onTapGesture: next
                        )
                        
                        CommonUseStep(
                            title: Text("Presets for Daily Activity"),
                            readTime: .minutes(2)
                        )
                        .disabled(true)
                        
                        CommonUseStep(
                            title: Text("Presets for Exercise"),
                            readTime: .minutes(5)
                        )
                        .disabled(true)
                    }
                    
                case .presetsForIllness:
                    Text("Physical stress, like illness, can cause glucose to rise.")
                    
                    InsetContent(alignment: .leading) {
                        Text("**Example:** Paloma Porpoise notices her glucose is higher than normal and wants to create a preset to manage it while she's sick.")
                    }
                    
                    Text("Let's look at the settings that will impact Paloma's insulin delivery.")
                    
                case .overallInsulin:
                    Text("Paloma wants \(appName) to know she needs more insulin than usual.")
                    
                    TherapySettingsExampleView(
                        title: NSLocalizedString("Paloma’s Current Therapy Settings", comment: ""),
                        components: [
                            .basalRate(0.5),
                            .carbRatio(13),
                            .isf(50)
                        ]
                    )
                    
                    Text("She can do this by raising her **Overall Insulin** setting. This tells \(appName) to deliver more than her usual amount, making her insulin settings stronger.")
                    
                    if let image = Image("PresetsTrainingIllnessOverallInsulin") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    TherapySettingsExampleView(
                        title: NSLocalizedString("Paloma’s Adjusted Therapy Settings", comment: ""),
                        components: [
                            .basalRate(0.6),
                            .carbRatio(12),
                            .isf(45)
                        ],
                        style: .adjusted
                    )
                    
                case .correctionRange:
                    Text("While sick, Paloma expects to eat less or not absorb everything she eats.")
                    
                    TherapySettingsExampleView(
                        title: NSLocalizedString("Paloma’s Current Therapy Settings", comment: ""),
                        component: .correctionRange(105...110)
                    )
                    
                    Text("To help prevent lows, she will increase her correction range.")
                    
                    if let image = Image("PresetsTrainingIllnessCorrectionRange") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    TherapySettingsExampleView(
                        title: NSLocalizedString("Paloma’s Adjusted Therapy Settings", comment: ""),
                        component: .correctionRange(130...140),
                        style: .adjusted
                    )
                    
                case .duration:
                    Text("You can choose how long your preset lasts.")
                    
                    Text("Since Paloma doesn't know when she'll feel better, she sets hers to “Until I Turn Off”.")
                    
                    if let image = Image("PresetsTrainingIllnessDuration1") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Text("To be safe, \(appName) will remind her at 8 hours that the preset is still running.")
                    
                    if let image = Image("PresetsTrainingIllnessDuration2") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Text("While turned on, Paloma’s preset will display on the home screen and in her Presets list.")
                    
                case .impactOnBolusing:
                    Text("Later that day, Paloma eats a meal with about 30g of carbs.")
                    
                    Text("How does her preset impact her bolus recommendation?")
                    
                    Text("Her preset is set to **110%**, which is more than she usually needs. This means \(appName) will make her basal rates, carb ratio, and insulin sensitivity factor (ISF) stronger. ")
                    
                    TherapySettingsExampleView(
                        title: NSLocalizedString("Her bolus recommendation is higher than usual because her overall insulin is set higher.", comment: ""),
                        component: .bolusRecommendation(
                            starting: 3.9,
                            ending: 4.3,
                            action: NSLocalizedString("With Preset On", comment: "")
                        ),
                        style: .adjusted
                    )
                }
            case .dailyActivities(let dailyActivities):
                switch dailyActivities {
                case .commonUses:
                    Text("You can use presets for a variety of situations. Explore the uses below to learn tips for these common scenarios.")
                    
                    VStack(spacing: 16) {
                        CommonUseStep(
                            title: Text("Presets for Illness"),
                            readTime: .minutes(3)
                        )
                        
                        CommonUseStep(
                            title: Text("Presets for Daily Activity"),
                            readTime: .minutes(2),
                            onTapGesture: next
                        )
                        
                        CommonUseStep(
                            title: Text("Presets for Exercise"),
                            readTime: .minutes(5)
                        )
                        .disabled(true)
                    }
                    
                case .presetsForDailyActivities:
                    Text("For some people, routine chores and everyday activities can affect glucose levels similar to exercise.")
                    
                    InsetContent(alignment: .leading) {
                        Text("**Example:** Omar Octopus wants to create a preset for some yard work he’ll be doing around the house.")
                    }
                    
                    Text("Let's look at the settings that will impact Omar’s insulin delivery.")
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Learn More")
                            .font(.headline.weight(.semibold))
                        
                        PlayMediaButton(
                            image: Image("ADLs"),
                            title: Text("Managing Activities of Daily Living"),
                            duration: .minutes(5) + .seconds(36)
                        )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.presets.opacity(0.1))
                    )
                    
                case .overallInsulin:
                    Text("Omar asks himself, **do I expect I will need more or less insulin than usual?**")
                    
                    Text("Since he doesn’t plan to push himself too hard, he expects his insulin needs to stay the same, so he leaves the setting at 100%.")
                    
                    if let image = Image("PresetsTrainingDailyActivityOverallInsulin") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Callout(.note) {
                        Text("Pay attention to your insulin needs before and after exercising, playing sports, or doing unusually hard physical labor.")
                    }
                    .padding(.horizontal, -16)
                    
                case .correctionRange:
                    Text("For activities that raise your risk of going low, you can set a higher temporary correction range.")
                    
                    Text("This range is usually higher than your correction range when you are not exercising.")
                    
                    Text("Because Omar has gone low while working outdoors in the past, he raises his preset correction range to help prevent another low.")
                    
                    TherapySettingsExampleView(
                        title: NSLocalizedString("Omar’s Current Therapy Settings", comment: ""),
                        component: .correctionRange(110...120)
                    )
                    
                    Text("Omar sets his correction range a little higher, to \(displayGlucosePreference.format(LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 110), includeUnit: false))-\(displayGlucosePreference.format(LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), includeUnit: false)) \(displayGlucosePreference.unit.localizedShortUnitString). This tells \(appName) to step in sooner.")
                    
                    if let image = Image("PresetsTrainingDailyActivityCorrectionRange") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                case .savedPresets:
                    if let image = Image("PresetsTrainingDailyActivitySavedPresets") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Text("Once saved, Omar’s new preset will display in his Presets lists.")
                    
                    Callout(.note) {
                        Text("If your activity has a higher risk of low glucose, start a physical activity preset at least **1 hour before you begin** and keep it on until you finish.")
                        
                        Text("If you expect your glucose to rise during the activity, you may not need a preset.")
                    }
                    .padding(.horizontal, -16)
                    
                }
            case .exercise(let exercise):
                switch exercise {
                case .commonUses:
                    Text("Presets can be used for a variety of situations. Explore the uses below to learn tips for these common scenarios.")
                    
                    VStack(spacing: 16) {
                        CommonUseStep(
                            title: Text("Presets for Illness"),
                            readTime: .minutes(3)
                        )
                        
                        CommonUseStep(
                            title: Text("Presets for Daily Activity"),
                            readTime: .minutes(2)
                        )
                        
                        CommonUseStep(
                            title: Text("Presets for Exercise"),
                            readTime: .minutes(5),
                            onTapGesture: next
                        )
                    }
                case .presetsForExercise:
                    Text("Exercise is a common reason to use a preset.")
                    
                    Text("Different kinds of exercise and their intensity levels can affect your glucose levels in different ways.")
                    
                    Text("Depending on the activity, you may notice a few common patterns when it comes to your insulin needs:")
                    
                    BulletedListView {
                        Text("no change needed")
                        Text("you need **less** insulin than usual")
                        Text("you need **more** insulin than usual")
                    }
                    
                    Callout(.note) {
                        Text("These patterns are based on published exercise consensus guidelines and are meant to be used as a starting point. What works for one person may not work for you.")
                    }
                    .padding(.horizontal, -16)
                    
                case .perceivedIntensity:
                    Text("Recognizing how hard you feel you're working during exercise can help you understand its impact on your glucose levels.")
                    
                    Text("Consider an exercise you do regularly and think about how hard you push yourself.")
                    
                    Text("Use the slider to rate the effort on a scale of 0–10, with 10 being the hardest you’ve ever worked.")
                    
                    IntensityInfo()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Learn More")
                            .font(.headline.weight(.semibold))
                        
                        PlayMediaButton(
                            image: Image("Same Activity Different Intensity"),
                            title: Text("Same Activity, Different Intensity"),
                            duration: .minutes(6) + .seconds(34)
                        )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.presets.opacity(0.1))
                    )
                    
                case .lightToModerateExercise:
                    if let image = Image("PresetsTrainingExerciseLightToModerateHero") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Text("Light-to-moderate intensity exercise can cause a drop in glucose levels. This is because your body uses glucose (or sugar) for energy during physical activity.")
                    
                    InsetContent {
                        VStack(spacing: 4) {
                            Text("Aerobic")
                                .font(.title2.bold())
                            
                            Text("Continuous or exercise without breaks")
                                .frame(maxWidth: .infinity)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Bullet(color: .secondary)
                                
                                Text("Walking")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Bullet(color: .secondary)
                                
                                Text("Hiking")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Bullet(color: .secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Jogging")
                                    
                                    HStack(alignment: .center, spacing: 2) {
                                        Text("\(Image(systemName: "lightbulb.max"))")
                                             
                                        Text(" **Tip** Use your \(Image(systemName: "figure.run")) **Jogging** preset")
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background(Color(UIColor.secondarySystemBackground).cornerRadius(5))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Bullet(color: .secondary)
                                
                                Text("Swimming")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    Text("For these activities, consider setting your insulin needs to **less than 100%**.")
                    
                    if let image = Image("PresetsTrainingExerciseLightToModerate") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Callout(.note) {
                        Text("These recommendations should be used as a starting point. Checking your glucose during exercise will help you find the settings that work best for you.")
                    }
                    .padding(.horizontal, -16)
                    
                case .highIntensityExercise:
                    if let image = Image("PresetsTrainingExerciseHighHero") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Text("High-intensity exercise means pushing yourself to your **maximum effort**. It is so hard that talking is nearly impossible, and you can’t keep it up for very long.")
                    
                    Text("During this kind of hard exercise, your body may release hormones that raise glucose. This is more common in the morning before eating.")
                    
                    InsetContent {
                        VStack(spacing: 4) {
                            Text("Aerobic")
                                .font(.title2.bold())
                            
                            Text("Explosive sprints or bursts")
                                .frame(maxWidth: .infinity)
                        }
                        
                        BulletedListView(bulletColor: .secondary) {
                            Text("Power lifting")
                            Text("CrossFit")
                            Text("100m sprint")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Text("For these activities, consider setting your insulin needs to **more than 100%**.")
                    
                    Text("That said, insulin needs vary from person to person. Some people find they don’t need to adjust their insulin at all for high-intensity exercise.")
                    
                    Text("If you haven’t noticed a rise in glucose with high-intensity exercise, it may be due to:")
                    
                    BulletedListView {
                        Text("Starting your exercise with high active insulin")
                        Text("Automated insulin adjustments by \(appName) reduce a noticeable rise in glucose")
                        Text("The exercise may not be vigorous enough to produce these results")
                    }
                    
                    if let image = Image("PresetsTrainingExerciseHigh") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Text("When using high-insulin presets, **you may not need to start your preset 1 hour before**.")
                    
                    Callout(.note) {
                        Text("These recommendations should be used as a starting point. Checking your glucose during exercise will help you find the settings that work best for you.")
                    }
                    .padding(.horizontal, -16)
                    
                case .mixedIntensityExercise:
                    if let image = Image("PresetsTrainingExerciseMixedHero") {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Text("Mixed-intensity exercise may cause only small changes in glucose levels. Your glucose may go up or down.")
                    
                    InsetContent {
                        VStack(spacing: 4) {
                            Text("Aerobic")
                                .font(.title2.bold())
                            
                            Text("Combination of high and low intensity")
                                .frame(maxWidth: .infinity)
                        }
                        
                        BulletedListView(bulletColor: .secondary) {
                            Text("Soccer")
                            Text("Interval Training ")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Text("For mixed-intensity activity:")
                    
                    BulletedListView {
                        Text("If your glucose goes up, you may only need a small increase in insulin — less than you would for high-intensity activity.")
                        
                        Text("If your glucose goes down, you may only need a small decrease in insulin — less than you would for low to moderate-intensity activity.")
                    }
                    
                    Callout(.note) {
                        Text("These recommendations should be used as a starting point. Checking your glucose during exercise will help you find the settings that work best for you.")
                    }
                    .padding(.horizontal, -16)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Learn More")
                            .font(.headline.weight(.semibold))
                        
                        PlayMediaButton(
                            image: Image("Mixed Exercise"),
                            title: Text("Navigating the Challenges of Mixed Exercise"),
                            duration: .minutes(3) + .seconds(27)
                        )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.presets.opacity(0.1))
                    )
                    
                case .exerciseAndGlucoseActiveInsulin:
                    Text("When using a preset for activity, keep in mind four key factors that may impact your  glucose.")
                    
                    TintedContent(
                        tint: colorPalette.insulinTintColor,
                        icon: Image(systemName: "cross.vial"),
                        title: Text("Active Insulin")
                    ) {
                        Text("If you have active insulin in your body when you start exercising, you generally have an increased risk of low glucose.")
                        
                        TintedTip(text: Text("**Tip:** Try exercising when your active insulin is close to zero at the start of an activity."))
                    }
                    
                case .exerciseAndGlucoseTimeOfDay:
                    Text("When using a preset for activity, keep in mind four key factors that may impact your  glucose.")
                    
                    TintedContent(
                        tint: colorPalette.carbTintColor,
                        icon: Image(systemName: "clock"),
                        title: Text("Time of Day")
                    ) {
                        Text("Morning exercise before eating (like a fasted jog) usually causes a smaller drop in glucose levels and may even promote a rise, compared to afternoon exercise.")
                        
                        if dynamicTypeSize < .accessibility1 {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Morning Exercise")
                                        .foregroundStyle(colorPalette.carbTintColor)
                                        .font(.subheadline.weight(.semibold))
                                    
                                    Text("Smaller glucose drop")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground)))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Afternoon Exercise")
                                        .foregroundStyle(colorPalette.guidanceColors.critical)
                                        .font(.subheadline.weight(.semibold))
                                    
                                    Text("Larger glucose drop")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground)))
                            }
                        } else {
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Morning Exercise")
                                        .foregroundStyle(colorPalette.carbTintColor)
                                        .font(.subheadline.weight(.semibold))
                                    
                                    Text("Smaller glucose drop")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground)))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Afternoon Exercise")
                                        .foregroundStyle(colorPalette.guidanceColors.critical)
                                        .font(.subheadline.weight(.semibold))
                                    
                                    Text("Larger glucose drop")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground)))
                            }
                        }
                        
                        TintedTip(text: Text("**Try:** If you often experience low glucose, consider exercising earlier in the day before eating."))
                    }
                    
                case .exerciseAndGlucoseMealTiming:
                    Text("When using a preset for activity, keep in mind four key factors that may impact your  glucose.")
                    
                    TintedContent(
                        tint: .orange,
                        icon: Image(systemName: "fork.knife"),
                        title: Text("Active Insulin")
                    ) {
                        Text("If you often experience low glucose, you may need to reduce how much insulin you deliver for meals eaten 1-2 hours before exercising.")
                        
                        VStack(spacing: 4) {
                            Text("Recommended Insulin Reduction")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                            
                            Text("25-33%")
                                .font(.title.weight(.heavy))
                                .foregroundStyle(Color.orange)
                            
                            Text("if eating less than 2 hours before exercise")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground)))
                        
                        TintedTip(text: Text("**Try:** Reducing your meal bolus if you expect your glucose to drop."))
                    }
                    
                case .exerciseAndGlucoseCompetitionStress:
                    Text("When using a preset for activity, keep in mind four key factors that may impact your  glucose.")
                    
                    TintedContent(
                        tint: colorPalette.glucoseTintColor,
                        icon: Image(systemName: "trophy"),
                        title: Text("Competition Stress")
                    ) {
                        Text("Stress during a game, match or tournament causes your body to release hormones like adrenaline and cortisol, which may raise your glucose and cause \(appName) to increase insulin delivery.")
                        
                        BulletedListView(bulletColor: colorPalette.glucoseTintColor, bulletOpacity: 1) {
                            Text("Monitor your glucose and active insulin at the start of a competition day")
                            
                            Text("Stay hydrated")
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground)))
                        
                        TintedTip(text: Text("**Tip: If glucose rises to >270 mg/dl,** check \(appName) to see if a bolus is recommended to bring your glucose back into range."))
                    }
                    
                case .preventingLows:
                    Text("If you usually experience lows while exercising, watch your glucose levels closely during exercise and consider eating around 3 to 20g of fast-acting carbs.")
                    
                    Group {
                        if dynamicTypeSize < .accessibility1 {
                            HStack(alignment: .bottom, spacing: 12) {
                                InsetContent(spacing: 8) {
                                    Text("Stable Glucose")
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxHeight: .infinity)
                                    
                                    Image("glucose-stable")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .foregroundStyle(colorPalette.glucoseTintColor)
                                    
                                    VStack(spacing: 0) {
                                        Text("3-6")
                                            .font(.headline.weight(.semibold))
                                        
                                        Text("grams")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                InsetContent(spacing: 8) {
                                    Text("Falling Slowly")
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxHeight: .infinity)
                                    
                                    Image("glucose-stable")
                                        .resizable()
                                        .scaledToFit()
                                        .rotationEffect(.degrees(30))
                                        .frame(width: 28, height: 28)
                                        .foregroundStyle(colorPalette.glucoseTintColor)
                                    
                                    VStack(spacing: 0) {
                                        Text("6-9")
                                            .font(.headline.weight(.semibold))
                                        
                                        Text("grams")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                InsetContent(spacing: 8) {
                                    Text("Falling / Falling Quickly")
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxHeight: .infinity)
                                    
                                    HStack(spacing: 6) {
                                        Image("glucose-stable")
                                            .resizable()
                                            .scaledToFit()
                                            .rotationEffect(.degrees(90))
                                            .frame(width: 28, height: 28)
                                        
                                        Image("glucose-falling-fast")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 28, height: 28)
                                    }
                                    .foregroundStyle(colorPalette.glucoseTintColor)
                                    
                                    VStack(spacing: 0) {
                                        Text("9-20")
                                            .font(.headline.weight(.semibold))
                                        
                                        Text("grams")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        } else {
                            VStack(spacing: 12) {
                                InsetContent(spacing: 8) {
                                    Text("Stable Glucose")
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxHeight: .infinity)
                                    
                                    Image("glucose-stable")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .foregroundStyle(colorPalette.glucoseTintColor)

                                    Text("3-6")
                                        .font(.headline.weight(.semibold))
                                    + Text(" grams")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                
                                InsetContent(spacing: 8) {
                                    Text("Falling Slowly")
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxHeight: .infinity)
                                    
                                    Image("glucose-stable")
                                        .resizable()
                                        .scaledToFit()
                                        .rotationEffect(.degrees(30))
                                        .frame(width: 28, height: 28)
                                        .foregroundStyle(colorPalette.glucoseTintColor)
                                    
                                    Text("6-9")
                                        .font(.headline.weight(.semibold))
                                    + Text(" grams")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                
                                InsetContent(spacing: 8) {
                                    Text("Falling / Falling Quickly")
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxHeight: .infinity)
                                    
                                    HStack(spacing: 6) {
                                        Image("glucose-stable")
                                            .resizable()
                                            .scaledToFit()
                                            .rotationEffect(.degrees(90))
                                            .frame(width: 28, height: 28)
                                        
                                        Image("glucose-falling-fast")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 28, height: 28)
                                    }
                                    .foregroundStyle(colorPalette.glucoseTintColor)
                                    
                                    Text("9-20")
                                        .font(.headline.weight(.semibold))
                                    + Text(" grams")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .multilineTextAlignment(.center)
                    
                    Text("Check your glucose levels around 20 to 30 min after eating. If you're still low, consider eating the same amount.")
                    
                    Callout(.note) {
                        Text("If your glucose isn't dropping, eating too many carbs can raise your blood sugar, trigger more insulin, and increase the risk of low blood sugar during or after the activity.")
                    }
                    .padding(.horizontal, -16)
                    
                case .unplannedActivity:
                    Text("Planning for physical activity can be tough. If you forget to set a preset ahead of time, consider these strategies:")
                    
                    InsetContent(padding: 16) {
                        HStack(spacing: 16) {
                            Image("presets-selected")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .foregroundStyle(Color.presets)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start Preset")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fontWeight(.semibold)
                                
                                Text("Turn on the preset as soon as you remember and keep it on until the activity ends")
                            }
                        }
                    }
                    
                    InsetContent(padding: 16) {
                        HStack(spacing: 16) {
                            Image("candy-icon")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .foregroundStyle(colorPalette.carbTintColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("If glucose drops below 126 mg/dL")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fontWeight(.semibold)
                                
                                Text("Consider eating around 10 to 20 grams of fast-acting carbs")
                            }
                        }
                    }
                }
            }
        case .trainingComplete:
            Text("Congratulations! You've finished the Presets training.")
            
            VStack(alignment: .leading, spacing: 8) {
                Text("You can now:")
                
                BulletedListView {
                    Text("Edit presets")
                    Text("Create new presets")
                }
                .padding(.leading, 8)
            }
            
            Text("You may review the training materials again at any time via the Learning Hub, located at the bottom of the Preset screen.")
        }
    }
    
    var cta: PresetsTraining.CTA? {
        switch self {
        case .entryPoint: .start
        case .tier1(let tier1Chapter):
            switch tier1Chapter {
            case .introduction(let introduction):
                switch introduction {
                case .introduction,
                     .exercisingWithLoop,
                     .timingYourPresets,
                     .safeGlucoseRanges,
                     .performanceHistory: .continue
                case .complete: .closeOrContinue("Step 2", chapter: .introduction)
                }
            }
        case .tier2(let tier2Chapter):
            switch tier2Chapter {
            case .customizingPresets: .continue
            case .illness(let illness):
                switch illness {
                case .commonUses: nil
                case .presetsForIllness,
                     .overallInsulin,
                     .correctionRange,
                     .duration,
                     .impactOnBolusing: .continue
                }
            case .dailyActivities(let dailyActivities):
                switch dailyActivities {
                case .commonUses: nil
                case .presetsForDailyActivities,
                     .overallInsulin,
                     .correctionRange,
                     .savedPresets: .continue
                }
            case .exercise(let exercise):
                switch exercise {
                case .commonUses: nil
                case .presetsForExercise,
                     .perceivedIntensity,
                     .lightToModerateExercise,
                     .highIntensityExercise,
                     .mixedIntensityExercise,
                     .exerciseAndGlucoseActiveInsulin,
                     .exerciseAndGlucoseTimeOfDay,
                     .exerciseAndGlucoseMealTiming,
                     .exerciseAndGlucoseCompetitionStress,
                     .preventingLows,
                     .unplannedActivity: .continue
                }
            }
        case .trainingComplete: .close
        }
    }
}

extension PresetsTraining.Chapter: PresetsTrainingContent {
    @ViewBuilder
    func content(
        appName: String,
        displayGlucosePreference: DisplayGlucosePreference,
        colorPalette: LoopUIColorPalette,
        dynamicTypeSize: DynamicTypeSize,
        next: @escaping () -> Void
    ) -> some View {
        firstStep.content(
            appName: appName,
            displayGlucosePreference: displayGlucosePreference,
            colorPalette: colorPalette,
            dynamicTypeSize: dynamicTypeSize,
            next: next
        )
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
