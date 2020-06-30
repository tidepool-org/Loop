//
//  SettingsView.swift
//  LoopUI
//
//  Created by Rick Pasetto on 6/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import SwiftUI

public struct SettingsView: View, HorizontalSizeClassOverride {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            List {
                loopSection
                if viewModel.showWarning {
                    alertPermissionsSection
                }
                therapySettingsSection
                deviceSettingsSection
                supportSection
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle(Text(LocalizedString("Settings", comment: "Settings screen title")))
            .navigationBarHidden(false)
            .navigationBarItems(trailing: dismissButton)
            .environment(\.horizontalSizeClass, horizontalOverride)
        }
    }
    
}

extension SettingsView {
        
    private var dismissButton: some View {
        Button( action: { self.dismiss() }) {
            Text("Done").bold()
        }
    }
    
    private var loopSection: some View {
        Section (header: SectionHeader(label: viewModel.appNameAndVersion)) {
            Toggle(isOn: $viewModel.dosingEnabled) {
                Text(LocalizedString("Closed Loop", comment: "The title text for the looping enabled switch cell"))
            }
        }
    }
    
    private var alertPermissionsSection: some View {
        Section {
            NavigationLink(destination:
                NotificationsCriticalAlertPermissionsView(
                    viewModel: NotificationsCriticalAlertPermissionsViewModel()))
            {
                HStack {
                    Text(LocalizedString("Alert Permissions", comment: "Alert Permissions button text"))
                    if viewModel.showWarning {
                        Spacer()
                        Text(LocalizedString("⚠️", comment: "Warning symbol"))
                    }
                }
            }
        }
    }
        
    private var therapySettingsSection: some View {
        Section (header: SectionHeader(label: LocalizedString("Configuration", comment: "The title of the Configuration section in settings"))) {
            NavigationLink(destination: Text("Therapy Settings")) {
                LargeButton(action: { },
                            includeArrow: false,
                            image: Image(bundleString: "Therapy Icon"),
                            label: LocalizedString("Therapy Settings", comment: "Title text for button to Therapy Settings"),
                            details: LocalizedString("Diabetes Treatment", comment: "Descriptive text for Therapy Settings"))
            }
        }
    }
    
    private var deviceSettingsSection: some View {
        Section {
            pumpSection
            cgmSection
        }
    }
    
    private var pumpSection: some View {
        if viewModel.pumpManagerSettingsViewModel.isSetUp {
            // TODO: this "dismiss then call onTapped()" here is temporary, until we've completely gotten rid of SettingsTableViewController
            return LargeButton(action: { self.dismiss(); self.viewModel.pumpManagerSettingsViewModel.onTapped() },
                               image: Image(uiImage: viewModel.pumpManagerSettingsViewModel.image, bundleString: "Omnipod"),
                               label: viewModel.pumpManagerSettingsViewModel.name,
                               details: viewModel.pumpManagerSettingsViewModel.details)
        } else {
            // TODO: this "dismiss then call onTapped()" here is temporary, until we've completely gotten rid of SettingsTableViewController
            return LargeButton(action: { self.dismiss(); self.viewModel.pumpManagerSettingsViewModel.onTapped() },
                               image: Image(bundleString: "Omnipod"),
                               label: LocalizedString("Add Pump", comment: "Title text for button to add pump device"),
                               details: LocalizedString("Tap here to set up a pump", comment: "Descriptive text for button to add pump device"))
        }
    }
    
    private var cgmSection: some View {
        if viewModel.cgmManagerSettingsViewModel.isSetUp {
            // TODO: this "dismiss then call onTapped()" here is temporary, until we've completely gotten rid of SettingsTableViewController
            return LargeButton(action: { self.dismiss(); self.viewModel.cgmManagerSettingsViewModel.onTapped() },
                               image: Image(uiImage: viewModel.cgmManagerSettingsViewModel.image, bundleString: "Dexcom G6"),
                               label: viewModel.cgmManagerSettingsViewModel.name,
                               details: viewModel.cgmManagerSettingsViewModel.details)
        } else {
            // TODO: this "dismiss then call onTapped()" here is temporary, until we've completely gotten rid of SettingsTableViewController
            return LargeButton(action: { self.dismiss(); self.viewModel.cgmManagerSettingsViewModel.onTapped() },
                               image: Image(bundleString: "Dexcom G6"),
                               label: LocalizedString("Add CGM", comment: "Title text for button to add CGM device"),
                               details: LocalizedString("Tap here to set up a CGM", comment: "Descriptive text for button to add CGM device"))
        }
    }
    
    private var supportSection: some View {
        Section (header: SectionHeader(label: NSLocalizedString("Support", comment: "The title of the support section in settings"))) {
            NavigationLink(destination: Text("Support")) {
                Text(NSLocalizedString("Support", comment: "The title of the support section in settings"))
            }
        }
    }

}

fileprivate struct LargeButton: View {
    
    let action: () -> Void
    var includeArrow: Bool = true
    let image: Image
    let label: String
    let details: String

    // TODO: The design doesn't show this, but do we need to consider different values here for different size classes?
    static let spacing: CGFloat = 15
    static let imageWidth: CGFloat = 48
    static let imageHeight: CGFloat = 48
    static let topBottomPadding: CGFloat = 20
    
    public var body: some View {
        Button(action: action) {
            HStack {
                HStack(spacing: Self.spacing) {
                    image
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Self.imageWidth, height: Self.imageHeight)
                    VStack(alignment: .leading) {
                        Text(label)
                            .foregroundColor(.primary)
                        DescriptiveText(label: details)
                    }
                }
                if includeArrow {
                    Spacer()
                    // TODO: Ick. I can't use a NavigationLink because we're not Navigating, but this seems worse somehow.
                    Image(systemName: "chevron.right").foregroundColor(.gray).font(.footnote)
                }
            }
            .padding(EdgeInsets(top: Self.topBottomPadding, leading: 0, bottom: Self.topBottomPadding, trailing: 0))
        }
    }
}

extension Image {
    
    init(uiImage: UIImage? = nil, bundleString: String) {
        if let uiImage = uiImage {
            self = Image(uiImage: uiImage)
        } else {
            self = Image(frameworkImage: bundleString)
        }
    }
}

public struct SettingsView_Previews: PreviewProvider {
    public static var previews: some View {
        let viewModel = SettingsViewModel(appNameAndVersion: "Tidepool Loop v1.2.3.456",
                                          notificationsCriticalAlertPermissionsViewModel: NotificationsCriticalAlertPermissionsViewModel(),
                                          pumpManagerSettingsViewModel: DeviceViewModel(),
                                          cgmManagerSettingsViewModel: DeviceViewModel(),
                                          initialDosingEnabled: true)
        return Group {
            SettingsView(viewModel: viewModel)
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("SE light")
            
            SettingsView(viewModel: viewModel)
                .colorScheme(.dark)
                .previewDevice(PreviewDevice(rawValue: "iPhone XS Max"))
                .previewDisplayName("XS Max dark")
        }
    }
}
