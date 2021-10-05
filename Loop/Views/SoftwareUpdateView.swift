//
//  SoftwareUpdateView.swift
//  Loop
//
//  Created by Rick Pasetto on 10/4/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import SwiftUI

struct SoftwareUpdateView: View {
    
    private let padding: CGFloat = 5
    
    var settingsViewModel: SettingsViewModel

    var body: some View {
        List {
            softwareUpdateSection
            supportSection
        }
        .insetGroupedListStyle()
        .navigationBarTitle(Text("Software Update", comment: "Software update view title"))
    }
    
    private var softwareUpdateSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    settingsViewModel.versionUpdateViewModel.icon
                    updateHeader
                }
                .padding(.vertical, padding)
                
                DescriptiveText(label: updateBody)
                    .padding(.bottom, padding)
                    .foregroundColor(.gray)
                
                Divider()
                appStoreButton
            }
        }
    }
    
    @ViewBuilder
    private var updateHeader: some View {
        Text(settingsViewModel.versionUpdateViewModel.versionUpdate?.localizedDescription ?? "")
            .bold()
    }
    
    private var updateBody: String {
        switch settingsViewModel.versionUpdateViewModel.versionUpdate {
        case .criticalNeeded,  // for now...
                .supportedNeeded:
            return NSLocalizedString("Your Tidepool Loop app is out of date. It will continue to work, but we recommend updating to the new version.", comment: "Body for supported update needed")
        case .updateNeeded:
            return NSLocalizedString("Tidepool Loop has a new version ready for you. Please update through the App Store.", comment: "Body for information update needed")
        default:
            return ""
        }
    }
    
    private var appStoreButton: some View {
        Button( action: { settingsViewModel.versionUpdateViewModel.gotoAppStore() } ) {
            HStack {
                Text(NSLocalizedString("App Store to Download and Install", comment: "App Store to Download and Install button text"))
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray).font(.footnote)
            }
        }
        .accentColor(.primary)
        .padding(.vertical, padding)
    }
    
    // Note: this is mostly duplicated from SettingsView...
    private var supportSection: some View {
        Section(header: SectionHeader(label: NSLocalizedString("Support", comment: "The title of the support section in software update")),
                footer: Text("Have a question about an update? Let us know.", comment: "The footer of the support section in software update")) {
            NavigationLink(destination: SupportScreenView(didTapIssueReport: settingsViewModel.didTapIssueReport,
                                                          criticalEventLogExportViewModel: settingsViewModel.criticalEventLogExportViewModel,
                                                          availableSupports: settingsViewModel.availableSupports,
                                                          supportInfoProvider: settingsViewModel.supportInfoProvider))
            {
                Text(NSLocalizedString("Get Help", comment: "The title of the support item in settings"))
            }
        }
    }

}

struct SoftwareUpdateView_Previews: PreviewProvider {
    static var previews: some View {
        SoftwareUpdateView(settingsViewModel: SettingsViewModel.preview)
    }
}
