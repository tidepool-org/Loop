//
//  LoopStatusModalView.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2025-10-09.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI

struct LoopStatusModalView: View {
    @Environment(\.loopStatusColorPalette) private var loopStatusColors
    
    @State private var appear = false
    
    @Bindable var viewModel: LoopStatusModalViewModel
    
    let onDismiss: () -> Void
    let onNavigateToSettings: () -> Void

    private var freshnessColor: Color {
        switch viewModel.freshness {
        case .fresh: return .primary
        case .aging: return Color(loopStatusColors.warning)
        case .stale: return Color(loopStatusColors.error)
        }
    }
    
    private var deviceIssue: Bool {
        viewModel.isCGMInoperable || viewModel.isPumpInoperable || viewModel.hasBluetoothIssue
    }
    
    var body: some View {
        VStack {
            TimelineView(.animation) { _ in
                closeButton
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                LoopCircleView(closedLoop: viewModel.loopIconClosed, freshness: viewModel.freshness, deviceIssue: deviceIssue)
                    .environment(\.loopStatusColorPalette, loopStatusColors)
                    .padding(.bottom)
                
                if viewModel.loopIconClosed,
                   let lastLoopCompletedFormattedTime = viewModel.lastLoopCompletedFormattedTime
                {
                    lastLoopCompleted(lastLoopCompletedString: lastLoopCompletedFormattedTime)
                }
                
                automationDetails
                    .padding([.top, .horizontal])
                    .padding(.bottom, 10)
            }
        }
        .padding(10)
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
        .frame(maxWidth: 340)
        .animation(.spring(), value: appear)
        .onAppear {
            withAnimation {
                appear = true
            }
        }
    }
    
    private var closeButton: some View {
        Button("\(Image(systemName: "xmark"))") {
            withAnimation(.spring()) {
                appear = false
            }
            // Dismiss after animation delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onDismiss()
            }
        }
        .foregroundStyle(.primary)
    }
    
    private func lastLoopCompleted(lastLoopCompletedString: String) -> some View {
        Group {
            Text("Last loop completed")
            // ⚠️ arrow.triangle.2.circlepath is deprecated -- replace with "arrow.trianglehead.2.clockwise.rotate.90" once iOS 17 is dropped as a supported platform.
            Text("\(Image(systemName: "arrow.triangle.2.circlepath")) \(lastLoopCompletedString)")
                .foregroundStyle(freshnessColor)
            if viewModel.includeDateTimeStamp {
                Text(viewModel.formattedLastLoopCompletedDateTime)
                    .foregroundStyle(freshnessColor)
            } else if viewModel.freshness != .fresh {
                Text(viewModel.formattedLastLoopCompletedTime)
                    .foregroundStyle(freshnessColor)
            }
        }
        .font(.footnote)
        .fontWeight(.semibold)
    }
    
    private var automationDetails: some View {
        VStack(alignment: .center) {
            automationTitle
            automationMessage
        }
    }
        
    private var automationTitle: some View {
        Text(viewModel.copy.title)
            .font(.title2)
            .bold()
            .multilineTextAlignment(.center)
    }
    
    @ViewBuilder
    private var automationMessage: some View {
        let message = viewModel.copy.message

        // Use a localized search for the "Settings" word within the message
        let settingsWord = viewModel.localizedSettingsWord
        
        if let range = message.range(of: settingsWord) {
            let prefix = String(message[..<range.lowerBound])
            let suffix = String(message[range.upperBound...])
            
            Group {(
                Text(prefix) +
                Text(settingsWord)
                    .foregroundColor(.accentColor) +
                Text(suffix)
            )}
            .multilineTextAlignment(.center)
            .onTapGesture {
                onDismiss()
                onNavigateToSettings()
            }
        } else {
            Text(message)
                .multilineTextAlignment(.center)
        }
    }
}

@MainActor
@Observable
class LoopStatusModalViewModel {
    
    private weak var deviceManager: DeviceDataManager?
    private weak var loopManager: LoopDataManager?
    private weak var settingsManager: SettingsManager?
    
    init(deviceManager: DeviceDataManager?, loopManager: LoopDataManager?, settingsManager: SettingsManager?) {
        self.deviceManager = deviceManager
        self.loopManager = loopManager
        self.settingsManager = settingsManager
    }

    var lastLoopCompleted: Date? {
        loopManager?.lastLoopCompleted
    }
    
    var mostRecentGlucoseDataDate: Date? {
        loopManager?.mostRecentGlucoseDataDate
    }
    
    var loopIconClosed: Bool {
        settingsManager?.dosingEnabled ?? true
    }
    
    var hasBluetoothIssue: Bool {
        deviceManager?.hasBluetoothIssue ?? false
    }

    var isPumpInSignalLoss: Bool {
        deviceManager?.pumpManager?.inSignalLoss == true
    }
    
    var isPumpInoperable: Bool {
        deviceManager?.pumpManager == nil || deviceManager?.pumpManager?.isInoperable == true
    }
    
    var isDeliverySuspended: Bool {
        deviceManager?.isSuspended ?? false
    }

    var isCGMInWarmup: Bool {
        deviceManager?.cgmManager?.cgmManagerStatus.inSensorWarmup == true
    }
    
    var isCGMInSignalLoss: Bool {
        deviceManager?.cgmManager?.inSignalLoss == true
    }
    
    var isCGMInoperable: Bool {
        deviceManager?.cgmManager == nil || deviceManager?.cgmManager?.isInoperable == true
    }
    
    private var dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()
    
    private var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()
    
    var freshness: LoopCompletionFreshness {
        guard !isPumpInSignalLoss, !isCGMInSignalLoss else {
            return .stale
        }
        return LoopCompletionFreshness(age: ago)
    }
    
    var ago: TimeInterval? {
        guard loopIconClosed else {
            // when loop is open, the last glucose data date determines ago
            guard let mostRecentGlucoseDataDate else { return nil }
            return abs(min(0, mostRecentGlucoseDataDate.timeIntervalSinceNow))
        }

        // when loop is closed, the last loop completed date determines ago
        guard let lastLoopCompleted else { return nil }
        return abs(min(0, lastLoopCompleted.timeIntervalSinceNow))
    }
    
    var includeDateTimeStamp: Bool { // only include if last loop was before today
        guard let lastLoopCompleted else { return false }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return lastLoopCompleted < startOfToday
    }
    
    var formattedLastLoopCompletedDateTime: String {
        guard let lastLoopCompleted else { return "Unknown" }
        return String(format: NSLocalizedString("at %1$@", comment: "when adding the date and time. (1: the formatted date and time)"), dateTimeFormatter.string(from: lastLoopCompleted))
    }
    
    var formattedLastLoopCompletedTime: String {
        guard let lastLoopCompleted else { return "Unknown" }
        return String(format: NSLocalizedString("at %1$@", comment: "when adding a timestamp. (1: the formatted timestamp)"), timeFormatter.string(from: lastLoopCompleted))
    }
    
    var copy: (title: String, message: String) {
        guard loopIconClosed else {
            if hasBluetoothIssue || isPumpInoperable || isPumpInSignalLoss {
                return (titleDeviceIssue, NSLocalizedString("Tap your CGM or insulin pump status icons right away for more information and steps to resolve the issue.", comment: "message when automation is off and there is a bluetooth or pump issue"))
            } else if isDeliverySuspended {
                return (titleAutomationOff, NSLocalizedString("Resume insulin if you wish for the app to restart insulin delivery.\n\nIf you wish for the app to automate your insulin, go to Settings and toggle Closed Loop to on.", comment: "message when automation is off and insulin delivery is suspended"))
            } else if isCGMInoperable {
                return (titleDeviceIssue, NSLocalizedString("Tap your CGM status icon right away for more information and steps to resolve the issue.\n\nIn the meantime, your pump is still able to deliver insulin.", comment: "message when automation is off and CGM is inoperable"))
            } else if isCGMInSignalLoss {
                return (titleDeviceIssue, NSLocalizedString("Check for potential communication issues with your CGM.\n\nIn the meantime, your pump is still able to deliver insulin.", comment: "message when automation is off and CGM is in signal loss"))
            } else if isCGMInWarmup {
                return (titleAutomationOff, NSLocalizedString("Your CGM sensor is warming up.\n\nIn the meantime, your pump is still able to deliver insulin.\n\nIf you wish for the app to automate your insulin, go to Settings and toggle Closed Loop to on.", comment: "message when automation is off and CGM is in warmup"))
            } else if freshness == .fresh {
                return (titleAutomationOff, NSLocalizedString("Your pump and CGM will continue to operate, but the app will not adjust insulin dosing automatically.\n\nIf you wish for the app to automate your insulin, go to Settings and toggle Closed Loop to on.", comment: "message when automation is off, glucose value is fresh and devices are good"))
            } else {
                return (titleAutomationOff, NSLocalizedString("Make sure your devices are connected and within bluetooth range.\n\nIf you wish for the app to automate your insulin, go to Settings and toggle Closed Loop to on.", comment: "message when automation is off, glucose value is not fresh and devices are good"))
            }
        }
       
        if hasBluetoothIssue || isPumpInoperable {
            return (titleUnavailable, NSLocalizedString("Tap your CGM or insulin pump status icons right away for more information and steps to resolve the issue.", comment: "message when automation is on and there is a bluetooth or pump issue"))
        } else if isPumpInSignalLoss {
            return (titleUnsuccessful, NSLocalizedString("Tidepool Loop will continue trying to restore automation, but check for potential communication issues with your CGM or insulin pump.", comment: "message when automation is on and pump is in signal loss"))
        } else if isDeliverySuspended {
            return (titleUnavailable, NSLocalizedString("Automation is unavailable while your insulin is suspended.\n\nResume insulin if you wish for the app to automate insulin delivery.", comment: "message when automation is on and insulin delivery is suspended"))
        } else if isCGMInoperable {
            return (titleUnavailable, NSLocalizedString("Tap your CGM status icon right away for more information and steps to resolve the issue.\n\nIn the meantime, your pump is still able to deliver insulin.", comment: "message when automation is on and CGM is inoperable"))
        } else if isCGMInSignalLoss {
            return (titleUnsuccessful, NSLocalizedString("Tidepool Loop will continue trying to restore automation, but check for potential communication issues with your CGM.\n\nIn the meantime, your pump is still able to deliver insulin.", comment: "message when automation is on and CGM is in signal loss"))
        } else if isCGMInWarmup {
            return (titleUnavailable, NSLocalizedString("Automation is unavailable while your CGM sensor is warming up.\n\nIn the meantime, your pump is still able to deliver insulin.\n\nAutomation will resume when CGM readings are received.", comment: "message when automation is on and CGM is in warmup"))
        } else if freshness == .fresh {
            return (titleAutomationOn, NSLocalizedString("Tidepool Loop will actively adjust your insulin dosing in response to your glucose as often as every 5 minutes.", comment: "message when automation is on and the glucose value is fresh"))
        } else {
            return (titleUnsuccessful, NSLocalizedString("Tidepool Loop will continue trying to restore automation, but check for potential communication issues with your CGM or insulin pump.", comment: "message when automation is on and the glucose value is not fresh"))
        }
    }
    
    var titleDeviceIssue: String {
        return NSLocalizedString("Device Issue", comment: "title for when automation is off and there is a device issue")
    }
    
    var titleAutomationOff: String {
        return NSLocalizedString("Automation is off", comment: "title for when automation is off")
    }
    
    var titleUnavailable: String {
        return NSLocalizedString("Automation is unavailable", comment: "title for when automation is unavailable")
    }
    
    var titleUnsuccessful: String {
        return NSLocalizedString("Automation was unsuccessful", comment: "title for when automation was unsuccessful")
    }
    
    var titleAutomationOn: String {
        return NSLocalizedString("Automation is on", comment: "title for when automation is on")
    }
    
    var localizedSettingsWord: String {
        NSLocalizedString("Settings", comment: "Word referring to the app's settings screen")
    }

    var lastLoopCompletedFormattedTime: String? {
        guard let ago,
              let timeString = ago.truncatedTimeAgoString
        else { return nil }
        
        return NSLocalizedString("\(timeString) ago", comment: "last loop completed string")
    }
}
