//
//  ReferencesView.swift
//  Loop
//
//  Created by Cameron Ingham on 4/2/26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import SwiftUI

public struct ReferencesView: View {
    
    @State private var isExpanded: Bool = false
    @State private var selectedURL: URL? = nil
    
    private let references: [Text]
    
    init(_ references: [Text]) {
        self.references = references
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                Text("References")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                Text(Image(systemName: "chevron.up"))
                    .rotationEffect(.degrees(isExpanded ? 0 : 180))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }
            
            if isExpanded {
                Grid(horizontalSpacing: 4, verticalSpacing: 12) {
                    ForEach(references.indices, id: \.self) { referenceId in
                        GridRow(alignment: .top) {
                            Text("\(referenceId + 1).")
                            
                            references[referenceId]
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accentColor(.secondary)
                        }
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .animation(.default, value: isExpanded)
        .environment(\.openURL, OpenURLAction { url in
            self.selectedURL = url
            return .handled
        })
        .sheet(
            isPresented: Binding(
                get: { selectedURL != nil },
                set: { _,_ in selectedURL = nil }
            ),
            content: {
                NavigationStack {
                    WebView(url: selectedURL!)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    selectedURL = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                }
            }
        )
    }
}
