//
//  InsulinDeliveryLog.swift
//  Loop
//
//  Created by Cameron Ingham on 3/25/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import LoopKitUI
import SwiftUI

struct InsulinDeliveryLog: View {
    
    @State private var viewModel: InsulinDeliveryLogViewModel
    @State var showingFilterMenu = false
    
    let onTapGesture: (DoseEntry) -> Void
    
    init(viewModel: InsulinDeliveryLogViewModel, onTapGesture: @escaping (DoseEntry) -> Void) {
        self.viewModel = viewModel
        self.onTapGesture = onTapGesture
    }
    
    private func totalInsulinDeliveredLabel(from total: LoopQuantity) -> some View {
        LabeledContent {
            Text(viewModel.totalDeliveredFormatter.string(from: total) ?? "Unknown")
                .foregroundStyle(.secondary)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Total Insulin Delivery")
                
                Text("since \(Calendar.current.startOfDay(for: Date()).formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var filterMenu: some View {
        Menu("Filter") {
            Button { } label: {
                Text("Filter")
                Text("Event")
            }
            
            Picker("Filter", selection: $viewModel.selectedFilterOption) {
                ForEach(InsulinDeliveryLogViewModel.FilterOptions.allCases, id: \.self) { option in
                    Text(option.localizedMenuTitle)
                        .tag(option)
                }
            }
        }
    }
    
    private var deliveryLogHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("Insulin Delivery Log")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color(UIColor.label))
                
                Spacer()
                
                filterMenu
            }
            
            if viewModel.selectedFilterOption != .all {
                HStack(spacing: 8) {
                    Text("Filtered by:")
                        .foregroundStyle(Color(UIColor.systemGray))
                    
                    HStack(spacing: 4) {
                        Text(viewModel.selectedFilterOption.localizedMenuTitle)
                        
                        Button {
                            viewModel.selectedFilterOption = .all
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .padding(4)
                    .padding(.leading, 4)
                    .background(Color.accentColor.clipShape(Capsule()))
                    .foregroundStyle(Color(UIColor.systemBackground))
                }
                .font(.subheadline)
            }
        }
        .textCase(nil)
        .padding(.bottom, 4)
    }
    
    private var deliveryLog: some View {
        ForEach(viewModel.logEventDisplays) { displayEvent in
            switch displayEvent {
            case .title(_, let title):
                Text(title)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemGray5))
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            case .event(let event):
                ZStack {
                    InsulinDeliveryLogEventRow(event: event)
                    
                    if case let .pumpEvent(pumpEventType, doseEntry) = event.type, let doseEntry {
                        NavigationLink {
                            InsulinDeliveryEventDetailsView(pumpEventType: pumpEventType, doseEntry: doseEntry, onTapGesture: onTapGesture)
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                }
            }
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in
            return 0
        }
    }
    
    var body: some View {
        List {
            switch viewModel.state {
            case .loading:
                ActivityIndicator(isAnimating: .constant(true), style: .default)
                    .frame(maxWidth: .infinity)
            case .fetched(let data), .refreshing(let data):
                Section {
                    InsulinDeliveryOverview(
                        state: data.insulinDeliveryState,
                        time: data.insulinDeliveryStateUpdatedDate,
                        currentBasalRate: data.currentBasalRate,
                        lastAutoBolus: data.lastAutoBolus
                    )
                }
                
                Section {
                    totalInsulinDeliveredLabel(from: data.totalInsulinDelivered)
                }
            }
            
            Section {
                deliveryLog
            } header: {
                deliveryLogHeader
            }
        }
        .refreshable {
            await viewModel.fetchData()
        }
    }
}
