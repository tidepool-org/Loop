//
//  PresetsTraining.swift
//  Loop
//
//  Created by Cameron Ingham on 8/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI

@Observable
class PresetsTrainingCompletion {
    var completedChapters: [PresetsTraining.Chapter: Bool] {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "completedPresetTrainingChapters") else {
                return .default
            }
            
            return [PresetsTraining.Chapter: Bool](rawValue: rawValue) ?? .default
        }
        set {
            withMutation(keyPath: \.completedChapters) {
                UserDefaults.standard.setValue(newValue.rawValue, forKey: "completedPresetTrainingChapters")
            }
        }
    }
    
    var isComplete: Bool {
        completedChapters.values.allSatisfy({ $0 })
    }
    
    func complete(to chapter: PresetsTraining.Chapter) {
        guard FeatureFlags.allowDebugFeatures else { return }
        
        guard let chapterIndex = PresetsTraining.Chapter.allCases.firstIndex(of: chapter) else {
            return
        }
        
        for index in 0..<chapterIndex {
            let chapterToComplete = PresetsTraining.Chapter.allCases[index]
            completedChapters[chapterToComplete] = true
        }
        
        for index in chapterIndex..<PresetsTraining.Chapter.allCases.count {
            let chapterToIncomplete = PresetsTraining.Chapter.allCases[index]
            completedChapters[chapterToIncomplete] = false
        }
    }
}

@Observable
public class PresetsTraining {
    public enum Chapter: CaseIterable, Hashable, Sendable, Codable {
        case entry
        case introduction
        case customizingPresets
        case illness
        case dailyActivities
        case exercise
        case trainingComplete
        
        var title: Text {
            switch self {
            case .entry: Text("Entry")
            case .introduction: Text("Introduction")
            case .customizingPresets: Text("Customizing Presets")
            case .illness: Text("Presets for Illness")
            case .dailyActivities: Text("Presets for Daily Activities")
            case .exercise: Text("Presets for Exercise")
            case .trainingComplete: Text("Training Complete")
            }
        }
        
        var firstStep: Step {
            switch self {
            case .entry: .entryPoint
            case .introduction: .tier1(.introduction(.introduction))
            case .customizingPresets: .tier2(.customizingPresets(.customizingPresets))
            case .illness: .tier2(.illness(.commonUses))
            case .dailyActivities: .tier2(.dailyActivities(.commonUses))
            case .exercise: .tier2(.exercise(.commonUses))
            case .trainingComplete: .trainingComplete
            }
        }
    }
    
    enum Step: Hashable, Sendable {
        case entryPoint
        
        enum Tier1Chapter: Hashable, Sendable {
            enum Introduction: CaseIterable, Hashable, Sendable {
                case introduction
                case exercisingWithLoop
                case timingYourPresets
                case safeGlucoseRanges
                case performanceHistory
                case complete
            }
            
            case introduction(Introduction)
        }
        
        case tier1(Tier1Chapter)
        
        enum Tier2Chapter: Hashable, Sendable {
            enum CustomizingPresets: CaseIterable, Hashable, Sendable {
                case customizingPresets
                case overallInsulin
                case correctionRange
            }
            
            case customizingPresets(CustomizingPresets)
            
            enum Illness: CaseIterable, Hashable, Sendable {
                case commonUses
                case presetsForIllness
                case overallInsulin
                case correctionRange
                case duration
                case impactOnBolusing
            }
            
            case illness(Illness)
            
            enum DailyActivities: CaseIterable, Hashable, Sendable {
                case commonUses
                case presetsForDailyActivities
                case overallInsulin
                case correctionRange
                case savedPresets
            }
            
            case dailyActivities(DailyActivities)
            
            enum Exercise: CaseIterable, Hashable, Sendable {
                case commonUses
                case presetsForExercise
                case perceivedIntensity
                case lightToModerateExercise
                case highIntensityExercise
                case mixedIntensityExercise
                case exerciseAndGlucoseActiveInsulin
                case exerciseAndGlucoseTimeOfDay
                case exerciseAndGlucoseMealTiming
                case exerciseAndGlucoseCompetitionStress
                case preventingLows
                case unplannedActivity
            }
            
            case exercise(Exercise)
        }
        
        case tier2(Tier2Chapter)
        
        case trainingComplete
        
        func title(appName: String) -> String {
            switch self {
            case .entryPoint:
                NSLocalizedString("Presets Training", comment: "")
            case .tier1(let tier1Chapter):
                switch tier1Chapter {
                case .introduction(let introduction):
                    switch introduction {
                    case .introduction:
                        NSLocalizedString("Part 1: Introduction to Presets", comment: "")
                    case .exercisingWithLoop:
                        String(format: NSLocalizedString("Exercising with %1$@", comment: ""), appName)
                    case .timingYourPresets:
                        NSLocalizedString("Timing Your Presets for Exercise", comment: "")
                    case .safeGlucoseRanges:
                        NSLocalizedString("Safe Glucose Ranges for Exercise", comment: "")
                    case .performanceHistory:
                        NSLocalizedString("Performance History", comment: "")
                    case .complete:
                        NSLocalizedString("Part 1: Complete", comment: "")
                    }
                }
            case .tier2(let tier2Chapter):
                switch tier2Chapter {
                case .customizingPresets(let customizingPresets):
                    switch customizingPresets {
                    case .customizingPresets:
                        NSLocalizedString("Customizing Presets", comment: "")
                    case .overallInsulin:
                        NSLocalizedString("Overall Insulin", comment: "")
                    case .correctionRange:
                        NSLocalizedString("Correction Range", comment: "")
                    }
                case .illness(let illness):
                    switch illness {
                    case .commonUses:
                        NSLocalizedString("Common Uses of Presets", comment: "")
                    case .presetsForIllness:
                        NSLocalizedString("Presets for Illness", comment: "")
                    case .overallInsulin:
                        NSLocalizedString("Overall Insulin", comment: "")
                    case .correctionRange:
                        NSLocalizedString("Correction Range", comment: "")
                    case .duration:
                        NSLocalizedString("Duration", comment: "")
                    case .impactOnBolusing:
                        NSLocalizedString("Impact on Bolusing", comment: "")
                    }
                case .dailyActivities(let dailyActivities):
                    switch dailyActivities {
                    case .commonUses:
                        NSLocalizedString("Common Uses of Presets", comment: "")
                    case .presetsForDailyActivities:
                        NSLocalizedString("Presets for Daily Activity", comment: "")
                    case .overallInsulin:
                        NSLocalizedString("Overall Insulin", comment: "")
                    case .correctionRange:
                        NSLocalizedString("Correction Range", comment: "")
                    case .savedPresets:
                        NSLocalizedString("Saved Presets", comment: "")
                    }
                case .exercise(let exercise):
                    switch exercise {
                    case .commonUses:
                        NSLocalizedString("Common Uses of Presets", comment: "")
                    case .presetsForExercise:
                        NSLocalizedString("Presets for Exercise", comment: "")
                    case .perceivedIntensity:
                        NSLocalizedString("Perceived Intensity", comment: "")
                    case .lightToModerateExercise:
                        NSLocalizedString("Light-to-Moderate Intensity Exercise", comment: "")
                    case .highIntensityExercise:
                        NSLocalizedString("High-Intensity Exercise", comment: "")
                    case .mixedIntensityExercise:
                        NSLocalizedString("Mixed-Intensity Exercise", comment: "")
                    case .exerciseAndGlucoseActiveInsulin,
                         .exerciseAndGlucoseTimeOfDay,
                         .exerciseAndGlucoseMealTiming,
                         .exerciseAndGlucoseCompetitionStress:
                        NSLocalizedString("Exercise and Your Glucose Levels", comment: "")
                    case .preventingLows:
                        NSLocalizedString("Preventing Lows", comment: "")
                    case .unplannedActivity:
                        NSLocalizedString("Unplanned Activity", comment: "")
                    }
                }
            case .trainingComplete:
                NSLocalizedString("Training Complete", comment: "")
            }
        }
        
        func previous(startingFrom: Chapter) -> Step? {
            switch self {
            case .entryPoint: nil
            case .tier1(let tier1Chapter):
                switch tier1Chapter {
                case .introduction(let introduction):
                    switch introduction {
                    case .introduction: chapter != startingFrom ? nil : .entryPoint
                    case .exercisingWithLoop: .tier1(.introduction(.introduction))
                    case .timingYourPresets: .tier1(.introduction(.exercisingWithLoop))
                    case .safeGlucoseRanges: .tier1(.introduction(.timingYourPresets))
                    case .performanceHistory: .tier1(.introduction(.safeGlucoseRanges))
                    case .complete: .tier1(.introduction(.performanceHistory))
                    }
                }
            case .tier2(let tier2Chapter):
                switch tier2Chapter {
                case .customizingPresets(let customizingPresets):
                    switch customizingPresets {
                    case .customizingPresets: chapter != startingFrom ? nil : .tier1(.introduction(.complete))
                    case .overallInsulin: .tier2(.customizingPresets(.customizingPresets))
                    case .correctionRange: .tier2(.customizingPresets(.overallInsulin))
                    }
                case .illness(let illness):
                    switch illness {
                    case .commonUses: chapter != startingFrom ? nil : .tier2(.customizingPresets(.correctionRange))
                    case .presetsForIllness: .tier2(.illness(.commonUses))
                    case .overallInsulin: .tier2(.illness(.presetsForIllness))
                    case .correctionRange: .tier2(.illness(.overallInsulin))
                    case .duration: .tier2(.illness(.correctionRange))
                    case .impactOnBolusing: .tier2(.illness(.duration))
                    }
                case .dailyActivities(let dailyActivities):
                    switch dailyActivities {
                    case .commonUses: chapter != startingFrom ? nil : .tier2(.illness(.impactOnBolusing))
                    case .presetsForDailyActivities: .tier2(.dailyActivities(.commonUses))
                    case .overallInsulin: .tier2(.dailyActivities(.presetsForDailyActivities))
                    case .correctionRange: .tier2(.dailyActivities(.overallInsulin))
                    case .savedPresets: .tier2(.dailyActivities(.correctionRange))
                    }
                case .exercise(let exercise):
                    switch exercise {
                    case .commonUses: chapter != startingFrom ? nil : .tier2(.dailyActivities(.savedPresets))
                    case .presetsForExercise: .tier2(.exercise(.commonUses))
                    case .perceivedIntensity: .tier2(.exercise(.presetsForExercise))
                    case .lightToModerateExercise: .tier2(.exercise(.perceivedIntensity))
                    case .highIntensityExercise: .tier2(.exercise(.lightToModerateExercise))
                    case .mixedIntensityExercise: .tier2(.exercise(.highIntensityExercise))
                    case .exerciseAndGlucoseActiveInsulin: .tier2(.exercise(.mixedIntensityExercise))
                    case .exerciseAndGlucoseTimeOfDay: .tier2(.exercise(.exerciseAndGlucoseActiveInsulin))
                    case .exerciseAndGlucoseMealTiming: .tier2(.exercise(.exerciseAndGlucoseTimeOfDay))
                    case .exerciseAndGlucoseCompetitionStress: .tier2(.exercise(.exerciseAndGlucoseMealTiming))
                    case .preventingLows: .tier2(.exercise(.exerciseAndGlucoseCompetitionStress))
                    case .unplannedActivity: .tier2(.exercise(.preventingLows))
                    }
                }
            case .trainingComplete: chapter != startingFrom ? nil : .tier2(.exercise(.unplannedActivity))
            }
        }
        
        func next() -> (Step?, completedChapter: Chapter?) {
            switch self {
            case .entryPoint: (.tier1(.introduction(.introduction)), .entry)
            case .tier1(let tier1Chapter):
                switch tier1Chapter {
                case .introduction(let introduction):
                    switch introduction {
                    case .introduction: (.tier1(.introduction(.exercisingWithLoop)), nil)
                    case .exercisingWithLoop: (.tier1(.introduction(.timingYourPresets)), nil)
                    case .timingYourPresets: (.tier1(.introduction(.safeGlucoseRanges)), nil)
                    case .safeGlucoseRanges: (.tier1(.introduction(.performanceHistory)), nil)
                    case .performanceHistory: (.tier1(.introduction(.complete)), nil)
                    case .complete: (.tier2(.customizingPresets(.customizingPresets)), .introduction)
                    }
                }
            case .tier2(let tier2Chapter):
                switch tier2Chapter {
                case .customizingPresets(let customizingPresets):
                    switch customizingPresets {
                    case .customizingPresets: (.tier2(.customizingPresets(.overallInsulin)), nil)
                    case .overallInsulin: (.tier2(.customizingPresets(.correctionRange)), nil)
                    case .correctionRange: (.tier2(.illness(.commonUses)), .customizingPresets)
                    }
                case .illness(let illness):
                    switch illness {
                    case .commonUses: (.tier2(.illness(.presetsForIllness)), nil)
                    case .presetsForIllness: (.tier2(.illness(.overallInsulin)), nil)
                    case .overallInsulin: (.tier2(.illness(.correctionRange)), nil)
                    case .correctionRange: (.tier2(.illness(.duration)), nil)
                    case .duration: (.tier2(.illness(.impactOnBolusing)), nil)
                    case .impactOnBolusing: (.tier2(.dailyActivities(.commonUses)), .illness)
                    }
                case .dailyActivities(let dailyActivities):
                    switch dailyActivities {
                    case .commonUses: (.tier2(.dailyActivities(.presetsForDailyActivities)), nil)
                    case .presetsForDailyActivities: (.tier2(.dailyActivities(.overallInsulin)), nil)
                    case .overallInsulin: (.tier2(.dailyActivities(.correctionRange)), nil)
                    case .correctionRange: (.tier2(.dailyActivities(.savedPresets)), nil)
                    case .savedPresets: (.tier2(.exercise(.commonUses)), .dailyActivities)
                    }
                case .exercise(let exercise):
                    switch exercise {
                    case .commonUses: (.tier2(.exercise(.presetsForExercise)), nil)
                    case .presetsForExercise: (.tier2(.exercise(.perceivedIntensity)), nil)
                    case .perceivedIntensity: (.tier2(.exercise(.lightToModerateExercise)), nil)
                    case .lightToModerateExercise: (.tier2(.exercise(.highIntensityExercise)), nil)
                    case .highIntensityExercise: (.tier2(.exercise(.mixedIntensityExercise)), nil)
                    case .mixedIntensityExercise: (.tier2(.exercise(.exerciseAndGlucoseActiveInsulin)), nil)
                    case .exerciseAndGlucoseActiveInsulin: (.tier2(.exercise(.exerciseAndGlucoseTimeOfDay)), nil)
                    case .exerciseAndGlucoseTimeOfDay: (.tier2(.exercise(.exerciseAndGlucoseMealTiming)), nil)
                    case .exerciseAndGlucoseMealTiming: (.tier2(.exercise(.exerciseAndGlucoseCompetitionStress)), nil)
                    case .exerciseAndGlucoseCompetitionStress: (.tier2(.exercise(.preventingLows)), nil)
                    case .preventingLows: (.tier2(.exercise(.unplannedActivity)), nil)
                    case .unplannedActivity: (.trainingComplete, .exercise)
                    }
                }
            case .trainingComplete: (nil, .trainingComplete)
            }
        }
        
        var chapter: Chapter {
            switch self {
            case .entryPoint: .entry
            case .tier1: .introduction
            case .tier2(.customizingPresets): .customizingPresets
            case .tier2(.illness): .illness
            case .tier2(.dailyActivities): .dailyActivities
            case .tier2(.exercise): .exercise
            case .trainingComplete: .trainingComplete
            }
        }
        
        var contentBackground: Color {
            switch self {
            case .tier2(.dailyActivities(.commonUses)),
                 .tier2(.exercise(.commonUses)),
                 .tier2(.illness(.commonUses)):
                Color(UIColor.secondarySystemBackground)
            default:
                Color(UIColor.systemBackground)
            }
        }
    }

    var navigationPath: [Step]
    
    var currentStep: Step {
        navigationPath.last ?? startingAt.firstStep
    }
    
    private(set) var startingAt: Chapter = .entry
    
    let trainingCompletion: PresetsTrainingCompletion
    
    init(
        navigationPath: [Step] = [],
        startingAt: Chapter? = nil,
        trainingCompletion: PresetsTrainingCompletion = PresetsTrainingCompletion()
    ) {
        self.navigationPath = navigationPath
        self.trainingCompletion = trainingCompletion
        
        if let startingAt {
            self.startingAt = startingAt
        } else {
            var startingAt: Chapter?
            
            Chapter.allCases.reversed().forEach { chapter in
                if trainingCompletion.completedChapters[chapter] != true {
                    startingAt = chapter
                }
            }
            
            if let startingAt {
                self.startingAt = startingAt
            } else {
                self.startingAt = .entry
            }
        }
    }
    
    func next() {
        let (next, completedChapter) = currentStep.next()
        if let next {
            navigationPath.append(next)
        }
        
        if let completedChapter, trainingCompletion.completedChapters[completedChapter] != true {
            trainingCompletion.completedChapters[completedChapter] = true
        }
    }
}

extension Dictionary: @retroactive RawRepresentable where Key == PresetsTraining.Chapter, Value == Bool {
    public init?(rawValue: String) {
        guard
            let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode([Key: Value].self, from: data)
        else {
            return nil
        }
        
        self = result
    }

    public var rawValue: String {
        guard
            let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        
        return result
    }
    
    public static var `default`: Self = PresetsTraining.Chapter.allCases
        .reduce([:]) { partialResult, chapter in
            var partial = partialResult
            partial[chapter] = false
            return partial
        }
}
