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
}

@Observable
public class PresetsTraining {
    public enum Chapter: CaseIterable, Hashable, Sendable, Codable {
        case entry
        case introduction
        
        var firstStep: Step {
            switch self {
            case .entry: .entryPoint
            case .introduction: .tier1(.introduction(.introduction))
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
        
        func title(appName: String) -> String {
            switch self {
            case .entryPoint:
                return NSLocalizedString("Presets Training", comment: "")
            case .tier1(let tier1Chapter):
                switch tier1Chapter {
                case .introduction(let introduction):
                    switch introduction {
                    case .introduction:
                        return NSLocalizedString("Part 1: Introduction to Presets", comment: "")
                    case .exercisingWithLoop:
                        return String(format: NSLocalizedString("Exercising with %1$@", comment: ""), appName)
                    case .timingYourPresets:
                        return NSLocalizedString("Timing Your Presets for Exercise", comment: "")
                    case .safeGlucoseRanges:
                        return NSLocalizedString("Safe Glucose Ranges for Exercise", comment: "")
                    case .performanceHistory:
                        return NSLocalizedString("Performance History", comment: "")
                    case .complete:
                        return NSLocalizedString("Part 1: Complete", comment: "")
                    }
                }
            }
        }
        
        func previous(startingFrom: Chapter) -> Step? {
            switch self {
            case .entryPoint:
                return nil
            case .tier1(let tier1Chapter):
                switch tier1Chapter {
                case .introduction(let introduction):
                    switch introduction {
                    case .introduction:
                        guard chapter != startingFrom else { return nil }
                        return .entryPoint
                    case .exercisingWithLoop: return .tier1(.introduction(.introduction))
                    case .timingYourPresets: return .tier1(.introduction(.exercisingWithLoop))
                    case .safeGlucoseRanges: return .tier1(.introduction(.timingYourPresets))
                    case .performanceHistory: return .tier1(.introduction(.safeGlucoseRanges))
                    case .complete: return .tier1(.introduction(.performanceHistory))
                    }
                }
            }
        }
        
        func next() -> (Step?, completedChapter: Chapter?) {
            switch self {
            case .entryPoint: return (.tier1(.introduction(.introduction)), .entry)
            case .tier1(let tier1Chapter):
                switch tier1Chapter {
                case .introduction(let introduction):
                    switch introduction {
                    case .introduction: return (.tier1(.introduction(.exercisingWithLoop)), nil)
                    case .exercisingWithLoop: return (.tier1(.introduction(.timingYourPresets)), nil)
                    case .timingYourPresets: return (.tier1(.introduction(.safeGlucoseRanges)), nil)
                    case .safeGlucoseRanges: return (.tier1(.introduction(.performanceHistory)), nil)
                    case .performanceHistory: return (.tier1(.introduction(.complete)), nil)
                    case .complete: return (nil, .introduction)
                    }
                }
            }
        }
        
        var chapter: Chapter {
            switch self {
            case .entryPoint:
                return .entry
            case .tier1:
                return .introduction
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
            if trainingCompletion.completedChapters[.entry] != true {
                self.startingAt = .entry
            } else if trainingCompletion.completedChapters[.introduction] != true {
                self.startingAt = .introduction
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
