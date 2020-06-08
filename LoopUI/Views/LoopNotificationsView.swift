//
//  LoopNotificationsView.swift
//  LoopUI
//
//  Created by Rick Pasetto on 6/5/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import SwiftUI

public struct LoopNotificationsView: View, HorizontalSizeClassOverride {
    @Environment(\.dismiss) var dismiss
    
    private let backButtonText: String
    @ObservedObject private var viewModel: LoopNotificationsViewModel
    
    public init(backButtonText: String = "", viewModel: LoopNotificationsViewModel) {
        self.backButtonText = backButtonText
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationView {
            VStack {
                List {
//                    forceCriticalAlertsSection
//                    loopNotificationsSection
//                    notificationScheduleSection
                    notificationAndCriticalAlertPermissionSection
                    supportSection
                }
                .listStyle(GroupedListStyle())
                .navigationBarTitle(Text(LocalizedString("Loop Notifications", comment: "Loop Notifications settings screen title")))
                .navigationBarBackButtonHidden(false)
                .navigationBarHidden(false)
                .navigationBarItems(leading: dismissButton)
                .environment(\.horizontalSizeClass, horizontalOverride)
            }
        }
    }
    
    private var dismissButton: some View {
        Button( action: { self.dismiss() }) {
            Text(backButtonText)
        }
    }

    private var forceCriticalAlertsSection: some View {
        Section {
            Toggle(isOn: $viewModel.forceCriticalAlerts) {
                Text(LocalizedString("Make all notifications critical", comment: "Toggle for notifications to use critical alert"))
            }
            DescriptiveText(label: LocalizedString("When turned on, this will make every notification a Critical Alert. This means your phone will make a noise when any notifications are delivered, even when Silent or Do Not Disturb is turned on.\n\nLoop Hasn't Completed and Some Other Junk are always critical.", comment: "Description of the force critical alerts toggle"))
        }
    }
    
    private var loopNotificationsSection: some View {
        Section(header: SectionHeader(label: LocalizedString("Tidepool Loop Notifications", comment: "Section title for Tidepool Loop notifications")))
        {
            NavigationLink(destination: Text("A Thing screen")) {
                Text("A Thing")
            }
            NavigationLink(destination: Text("Another Thing screen")) {
                Text("Another Thing")
            }
        }
    }
    
    private var notificationScheduleSection: some View {
        Section {
            NavigationLink(destination: Text("Notification Schedule screen")) {
                Text(LocalizedString("Notification Schedule", comment: "Notification Schedule button text"))
            }
            DescriptiveText(label: LocalizedString("Create a different set of notification settings based on a schedule. For example, configure the schedule for  school, work, or at night.", comment: "Notification schedule descriptive text"))
        }
    }
    
    private var notificationAndCriticalAlertPermissionSection: some View {
        Section(header: SectionHeader(label: LocalizedString("Tidepool Loop Notifications", comment: "Section title for Tidepool Loop notifications"))) {
            NavigationLink(destination: Text("Notification & Critical Alert Permissions screen")) {
                Text(LocalizedString("Notification & Critical Alert Permissions", comment: "Notification & Critical Alert Permissions button text"))
            }
        }
    }
    
    private var supportSection: some View {
        Section(header: SectionHeader(label: LocalizedString("Support", comment: "Section title for Support"))) {
            NavigationLink(destination: Text("Get help with Loop Notifications screen")) {
                Text(LocalizedString("Get help with Loop Notifications", comment: "Get help with Loop notifications support button text"))
            }
            DescriptiveText(label: LocalizedString("Text description here.", comment: ""))
        }
    }
}

struct LoopNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            LoopNotificationsView(backButtonText: "Settings", viewModel: LoopNotificationsViewModel(initialValue: true, criticalAlertForcer: {_ in}))
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE"))
                .previewDisplayName("SE light")
            LoopNotificationsView(backButtonText: "Settings", viewModel: LoopNotificationsViewModel(initialValue: true, criticalAlertForcer: {_ in}))
                .colorScheme(.dark)
                .previewDevice(PreviewDevice(rawValue: "iPhone XS Max"))
                .previewDisplayName("XS Max dark")
        }
    }
}
