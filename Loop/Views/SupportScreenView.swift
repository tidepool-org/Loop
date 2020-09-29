//
//  SupportScreenView.swift
//  Loop
//
//  Created by Rick Pasetto on 8/18/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import SwiftUI

struct SupportScreenView: View, HorizontalSizeClassOverride {
    @Environment(\.dismiss) private var dismiss
    
    var didTapIssueReport: ((_ title: String) -> Void)?
    var criticalEventLogExportViewModel: CriticalEventLogExportViewModel
    
    var body: some View {
        List {
            Section {
                Button(action: {
                    self.didTapIssueReport?(NSLocalizedString("Issue Report", comment: "The title text for the issue report menu item"))
                }) {
                    Text("Issue Report", comment: "The title text for the issue report menu item")
                }
                
                adverseEventReport
                
                NavigationLink(destination: CriticalEventLogExportView(viewModel: self.criticalEventLogExportViewModel)) {
                    Text(NSLocalizedString("Export Critical Event Logs", comment: "The title of the export critical event logs in support"))
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle(Text("Support", comment: "Support screen title"))
        .environment(\.horizontalSizeClass, horizontalOverride)
    }
    
    private var adverseEventReport: some View {
        Button(action: {
            var urlString = "https://support.tidepool.org/hc/en-us/requests/new?ticket_form_id=360000551951"
            urlString.append("&request_custom_fields_360035401592=\(Bundle.main.localizedNameAndVersion)")
            if let urlString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                let url = URL(string: urlString)
            {
                UIApplication.shared.open(url)
            }
        }) {
            Text("Report an Adverse Event", comment: "The title text for the reporting of an adverse event menu item")
        }
    }
}

struct SupportScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SupportScreenView(criticalEventLogExportViewModel: CriticalEventLogExportViewModel(exporterFactory: MockCriticalEventLogExporterFactory()))
    }
}
