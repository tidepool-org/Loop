//
//  MediaContent.swift
//  Loop
//
//  Created by Cameron Ingham on 2/27/25.
//

import Foundation

struct MediaContent: Equatable, Hashable, Identifiable {
    let metadata: Metadata
    let animation: URL
    let audio: URL
    let transcript: Transcript?
    let closedCaptions: ClosedCaptions
    
    init(_ name: String) {
        self.metadata = Metadata(url: Bundle.main.url(forResource: name, withExtension: "json")!)!
        self.animation = Bundle.main.url(forResource: name, withExtension: "mp4")!
        self.audio = Bundle.main.url(forResource: name, withExtension: "mp3")!
        self.transcript = Transcript(url: Bundle.main.url(forResource: name, withExtension: "txt")!)
        self.closedCaptions = ClosedCaptions(url: Bundle.main.url(forResource: name, withExtension: "srt")!)
    }
    
    var id: Int {
        hashValue
    }
}

extension MediaContent {
    static let activitiesOfDailyLiving = MediaContent("ADLs")
    static let mixedExercise = MediaContent("Mixed Exercise")
    static let sameActivity = MediaContent("Same Activity Different Intensity")
}
