//
//  TranscriptExcerpt.swift
//  Loop
//
//  Created by Cameron Ingham on 7/16/25.
//

import Foundation

struct TranscriptExcerpt: Equatable, Hashable, RawRepresentable {
    
    let startTime: TimeInterval
    let text: String
    
    var rawValue: String {
        "[\(startTime.timecode(for: .transcript))] \(text)"
    }
    
    init(startTime: TimeInterval, text: String) {
        self.startTime = startTime
        self.text = text
    }
    
    init?(rawValue: String) {
        let fragments = rawValue.dropFirst().split(separator: "] ")
        self.startTime = TimeInterval(timecode: String(fragments[0]), style: .transcript)!
        self.text = String(fragments[1])
    }
}
