//
//  Transcript.swift
//  Loop
//
//  Created by Cameron Ingham on 7/16/25.
//

import Foundation

struct Transcript: Equatable, Hashable, RawRepresentable {
    
    let paragraphs: [TranscriptParagraph]
    
    var rawValue: String {
        paragraphs.map(\.rawValue).joined(separator: "\n\n")
    }
    
    init(paragraphs: [TranscriptParagraph]) {
        self.paragraphs = paragraphs
    }
    
    init(rawValue: String) {
        self.paragraphs = rawValue.split(separator: "\n\n").compactMap {
            TranscriptParagraph(rawValue: String($0))
        }
    }
    
    init(url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            assertionFailure("Could not generate data from file at URL: \(url.absoluteString)")
            self.init(paragraphs: [])
            return
        }
        
        let rawValue = String(data: data, encoding: .utf8)!
        self.init(rawValue: rawValue)
    }
    
    func currentExcerpt(at timecode: TimeInterval) -> TranscriptExcerpt {
        paragraphs.flatMap(\.excerpts).last(where: { $0.startTime <= timecode }) ?? TranscriptExcerpt(startTime: 0, text: "")
    }
}
