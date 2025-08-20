//
//  ActionView.swift
//  Loop
//
//  Created by Pete Schwamb on 8/15/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


import SwiftUI

struct ActionView: View {
    var body: some View {
        VStack {
            HStack {
                LoopStateView()
                
            }
            Button("Action 1") {
                // Handle action
            }
            Button("Action 2") {
                // Handle action
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
