//
//  TranscriptView.swift
//  Podcast Demo
//
//  Created by Cameron Ingham on 7/16/25.
//

import LoopKit
import SwiftUI

struct TranscriptView: View {
    @Binding var currentTime: TimeInterval
    
    let transcript: Transcript
    let onExcerptTap: (TranscriptExcerpt) -> Void
    let onExcerptChanged: (TranscriptExcerpt) -> Void
    
    private var currentTranscriptExcerpt: TranscriptExcerpt {
        transcript.currentExcerpt(at: currentTime)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(transcript.paragraphs, id: \.self) { paragraph in
                paragraph.excerpts.reduce(AttributedText("")) { partialResult, excerpt in
                    if partialResult != AttributedText("") {
                        return partialResult + AttributedText(" ") + excerptText(excerpt: excerpt)
                    } else {
                        return partialResult + excerptText(excerpt: excerpt)
                    }
                }
            }
        }
        .font(.title3.weight(.medium))
        .fontDesign(.serif)
        .onChange(of: currentTranscriptExcerpt) { _, newValue in
            onExcerptChanged(newValue)
        }
    }
    
    private func excerptText(excerpt: TranscriptExcerpt) -> AttributedText {
        AttributedText(excerpt.text) { attributedText in
            attributedText.foregroundColor = (currentTranscriptExcerpt == excerpt && currentTime != 0) ? .accentColor : .primary
        } onTap: {
            onExcerptTap(excerpt)
        }
    }
}

public struct AttributedText: View, Equatable {
    private var id: String
    private var attributedString: AttributedString
    private var onTap: (() -> Void)? = nil
    private var tapHandlers: [String: () -> Void] = [:]
    private var currentId: Int = 0
    
    private mutating func registerTapHandler(_ handler: @escaping () -> Void) -> String {
        let _id = "tappable-\(currentId)"
        currentId += 1
        tapHandlers[_id] = handler
        return _id
    }
    
    private func getTapHandler(for _id: String) -> (() -> Void)? {
        return tapHandlers[_id]
    }

    public init(
        _ string: String = "",
        modifier: ((_ text: inout AttributedString) -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        var attributedString = AttributedString(string)
        
        modifier?(&attributedString)
        
        self.id = string
        self.attributedString = attributedString
        self.onTap = onTap
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        var result = lhs
        var rhsString = rhs.attributedString
        
        if let onTap = rhs.onTap {
            let id = result.registerTapHandler(onTap)
            rhsString.link = URL(string: "tappable://\(id)")
        }
        
        result.attributedString.append(rhsString)
        return result
    }
    
    public var body: some View {
        Text(attributedString)
            .id(id)
            .environment(\.openURL, OpenURLAction { url in
                if let _id = url.host {
                    getTapHandler(for: _id)?()
                }
                return .discarded
            })
    }

    public func onTap(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.onTap = action
        return copy
    }

    public static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.attributedString == rhs.attributedString
    }
}
