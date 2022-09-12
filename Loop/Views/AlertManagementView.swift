//
//  AlertManagementView.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2022-09-09.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct AlertManagementView: View {
//    @Environment(\.dismissAction) private var dismiss
    @Environment(\.appName) private var appName

    private let backButtonText: String
    private let mode: NotificationsCriticalAlertPermissionsView.PresentationMode
    @ObservedObject private var checker: AlertPermissionsChecker

    @State private var tempMuteAllAlerts: Bool = false
    @State private var selectedDuration: TimeInterval
    private let allowedDurations: [TimeInterval] = [.minutes(30), .hours(1), .hours(2), .hours(4)]

    private var formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()

    private var formattedSelectedDuration: Binding<String> {
        Binding(
            get: { formatter.string(from: selectedDuration)! },
            set: { newValue in
                guard let selectedDurationIndex = formatterDurations.firstIndex(of: newValue)
                else { return }
                selectedDuration = allowedDurations[selectedDurationIndex]
            }
        )
    }

    private var formatterDurations: [String] {
        allowedDurations.compactMap { formatter.string(from: $0) }
    }

    public init(backButtonText: String = "", mode: NotificationsCriticalAlertPermissionsView.PresentationMode = .topLevel, checker: AlertPermissionsChecker) {
        self.backButtonText = backButtonText
        self.checker = checker
        self.mode = mode

        // this should be inputted
        self._selectedDuration = State(initialValue: .minutes(30))
    }

    var body: some View {
        List {
            alertPermissionsSection
            muteAlertsSection

            if tempMuteAllAlerts {
                mutePeriodSection
            }
        }
        .navigationTitle(NSLocalizedString("Alert Management", comment: "Title of alert management screen"))
    }

    private var alertPermissionsSection: some View {
        Section(footer: DescriptiveText(label: String(format: NSLocalizedString("Notifications give you important %1$@ app information without requiring you to open the app.", comment: "Alert Permissions descriptive text (1: app name)"), appName))) {
            NavigationLink(destination:
                            NotificationsCriticalAlertPermissionsView(mode: .flow, checker: checker))
            {
                HStack {
                    Text(NSLocalizedString("Alert Permissions", comment: "Alert Permissions button text"))
                    if checker.showWarning ||
                        checker.notificationCenterSettings.scheduledDeliveryEnabled {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.critical)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var muteAlertsSection: some View {
        Section(footer: muteAlertsSectionFooter) {
            Toggle(NSLocalizedString("Mute All Alerts", comment: "Label for toggle to mute all alerts"), isOn: $tempMuteAllAlerts)
        }
    }

    private var mutePeriodSection: some View {
        SingleSelectionCheckList(header: NSLocalizedString("Select Mute Period", comment: "List header for mute all alerts period"), footer: muteAlertsFooterString, items: formatterDurations, selectedItem: formattedSelectedDuration)
    }

    @ViewBuilder
    private var muteAlertsSectionFooter: some View {
        if !tempMuteAllAlerts {
            DescriptiveText(label: muteAlertsFooterString)
        }
    }

    private var muteAlertsFooterString: String {
        NSLocalizedString("No alerts will sound while muted. Once this period ends, your alerts and alarms will resume as normal.", comment: "Description of temporary mute alerts")
    }
}

struct AlertManagementView_Previews: PreviewProvider {
    static var previews: some View {
        AlertManagementView(checker: AlertPermissionsChecker())
    }
}
