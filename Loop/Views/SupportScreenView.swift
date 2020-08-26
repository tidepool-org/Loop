//
//  SupportScreenView.swift
//  Loop
//
//  Created by Rick Pasetto on 8/18/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import SwiftUI

struct SupportScreenView: View, HorizontalSizeClassOverride {
    @Environment(\.dismiss) private var dismiss
    
    var didTapIssueReport: ((_ title: String) -> Void)?
    
    var body: some View {
        List {
            Section {
                Button(action: {
                    self.didTapIssueReport?(NSLocalizedString("Issue Report", comment: "The title text for the issue report menu item"))
                }) {
                    Text("Issue Report", comment: "The title text for the issue report menu item")
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle(Text("Support", comment: "Support screen title"))
        .environment(\.horizontalSizeClass, horizontalOverride)
    }
}

struct SupportScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SupportScreenView()
    }
}
