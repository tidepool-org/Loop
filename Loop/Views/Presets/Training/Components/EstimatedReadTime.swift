//
//  EstimatedReadTime.swift
//  Loop
//
//  Created by Cameron Ingham on 8/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct EstimatedReadTime: View {
    
    private let readTimeString: String
    
    private let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .short
        return formatter
    }()
    
    init?(_ readTime: TimeInterval) {
        guard let readTimeString = formatter.string(from: readTime) else {
            return nil
        }
        
        self.readTimeString = readTimeString
    }
    
    var body: some View {
        Text(Image(systemName: "clock"))
            .foregroundStyle(Color.accentColor)
        + Text(" \(readTimeString) read")
            .foregroundStyle(Color.secondary)
    }
}

#Preview {
    EstimatedReadTime(.minutes(3))
}
