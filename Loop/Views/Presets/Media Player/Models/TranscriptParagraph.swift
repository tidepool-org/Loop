//
//  TranscriptParagraph.swift
//  Loop
//
//  Created by Cameron Ingham on 7/16/25.
//

import Foundation

struct TranscriptParagraph: Equatable, Hashable, RawRepresentable {
    
    let excerpts: [TranscriptExcerpt]
    
    var rawValue: String {
        excerpts.map(\.rawValue).joined(separator: " ")
    }
    
    init(excepts: [TranscriptExcerpt]) {
        self.excerpts = excepts
    }
    
    init(rawValue: String) {
        self.init(
            excepts: rawValue
                .split(separator: " [")
                .map({
                    let string = String($0)
                    if !string.hasPrefix("[") {
                        return "[\(string)"
                    } else {
                        return string
                    }
                })
                .compactMap({ TranscriptExcerpt(rawValue: $0) })
        )
    }
}
