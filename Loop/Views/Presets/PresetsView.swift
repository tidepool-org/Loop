//
//  PresetsView.swift
//  Loop
//
//  Created by Cameron Ingham on 10/23/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct PresetsView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = PresetsViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 36) {
                    if !viewModel.hasCompletedTraining {
                        PresetsTrainingCard(showTraining: $viewModel.showTraining)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(UIColor.secondarySystemBackground).ignoresSafeArea(edges: .all))
            .navigationTitle(Text("Presets", comment: "Presets screen title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showTraining) {
            PresetsTrainingView {
                viewModel.hasCompletedTraining = true
            }
        }
        .onAppear { // TODO: Remove this
            viewModel.hasCompletedTraining = false
        }
    }
}
