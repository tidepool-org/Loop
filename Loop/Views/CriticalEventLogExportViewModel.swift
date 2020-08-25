//
//  CriticalEventLogExportViewModel.swift
//  Loop
//
//  Created by Darin Krauss on 7/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import os.log
import Foundation
import SwiftUI
import LoopKit

protocol CriticalEventLogExporterFactory {
    func createExporter(to url: URL) -> CriticalEventLogExporter
}

extension CriticalEventLogExportManager: CriticalEventLogExporterFactory {}

public class CriticalEventLogExportViewModel: ObservableObject, Identifiable, CriticalEventLogExporterDelegate {
    @Published var progress: Double = 0
    @Published var remainingDurationString: String?
    @Published var url: URL? = nil
    @Published var showingError: Bool = false

    private let exporterFactory: CriticalEventLogExporterFactory
    private var exporter: CriticalEventLogExporter?
    private var progressStartDate: Date?
    private var progressLatestDate: Date?
    private var progressDuration: TimeInterval = 0
    private var remainingDuration: TimeInterval?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?

    private let log = OSLog(category: "CriticalEventLogExportManager")

    init(exporterFactory: CriticalEventLogExporterFactory) {
        self.exporterFactory = exporterFactory
    }

    func export() {
        dispatchPrecondition(condition: .onQueue(.main))

        reset()

        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForegroundNotificationReceived(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

        let filename = String(format: NSLocalizedString("Export-%1$@", comment: "The export file name formatted string (1: timestamp)"), self.timestampFormatter.string(from: Date()))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename).appendingPathExtension("zip")

        var exporter = exporterFactory.createExporter(to: url)
        exporter.delegate = self
        self.exporter = exporter

        beginBackgroundTask()

        DispatchQueue.global(qos: .utility).async {
            let error = exporter.export()
            if let error = error {
                self.log.error("Failure during critical event log export: %{public}@", String(describing: error))
            }

            DispatchQueue.main.async {
                self.endBackgroundTask()
                if !exporter.isCancelled {
                    if error != nil {
                        self.showingError = true
                    } else {
                        self.url = url
                    }
                }
            }
        }
    }

    func cancel() {
        dispatchPrecondition(condition: .onQueue(.main))

        exporter?.cancel()

        reset()
    }

    private func beginBackgroundTask() {
        dispatchPrecondition(condition: .onQueue(.main))

        endBackgroundTask()

        self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask {
            self.log.default("Invoked critical event log full export background task expiration handler")
            self.endBackgroundTask()
        }

        self.log.default("Begin critical event log full export background task")
    }

    private func endBackgroundTask() {
        dispatchPrecondition(condition: .onQueue(.main))

        if let backgroundTaskIdentifier = self.backgroundTaskIdentifier {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            self.backgroundTaskIdentifier = nil
            self.log.default("End critical event log full export background task")
        }
    }

    @objc private func willEnterForegroundNotificationReceived(_ notification: Notification) {
        beginBackgroundTask()
    }

    // Required due to the current design which creates all settings-related view models at once when the settings view is
    // about to be displayed. Since it is possible to invoke the export view multiple times from with the same settings view and
    // this view model contains view-specific state information it is therefore necessary to re-use the same view model each time
    // the export view thus necessitating the reset functionality.
    private func reset() {
        if let url = self.url {
            try? FileManager.default.removeItem(at: url)
        }

        self.progress = 0
        self.remainingDurationString = nil
        self.url = nil
        self.showingError = false

        self.exporter = nil
        self.progressStartDate =  nil
        self.progressDuration = 0
        self.remainingDuration = nil

        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - CriticalEventLogExporterDelegate

    private let progressBackgroundDuration: TimeInterval = .seconds(5)
    private let durationMinimum: TimeInterval = .seconds(5)
    private let remainingDurationDeltaMinimum: TimeInterval = .seconds(2)

    public func exportDidProgress(_ progress: Double) {
        DispatchQueue.main.async {
            guard let exporter = self.exporter, !exporter.isCancelled else {
                return
            }

            let now = Date()
            if self.progressStartDate == nil {
                self.progressStartDate = now
            }

            // If no progress in the last few seconds, then means we were backgrounded, so add to progress duration and refresh start date
            if let progressLatestDate = self.progressLatestDate, now > progressLatestDate.addingTimeInterval(self.progressBackgroundDuration) {
                self.progressDuration += progressLatestDate.timeIntervalSince(self.progressStartDate!)
                self.progressStartDate = now
            }

            self.progress = progress
            self.progressLatestDate = now

            // If no progress, then we have no idea when we will finish and bail (prevents divide by zero)
            guard progress > 0 else {
                self.remainingDuration = nil
                self.remainingDurationString = nil
                return
            }

            // If we haven't been exporting for long, then remaining duration may be wildly inaccurate so just bail
            let duration = self.progressDuration + self.progressLatestDate!.timeIntervalSince(self.progressStartDate!)
            guard duration > self.durationMinimum else {
                return
            }

            // If remaining duration hasn't changed much, then bail
            let remainingDuration = duration / progress - duration
            guard self.remainingDuration == nil || (remainingDuration - self.remainingDuration!).magnitude > self.remainingDurationDeltaMinimum else {
                return
            }

            self.remainingDuration = remainingDuration

            let remainingDurationString = self.remainingDurationToString(remainingDuration)
            if remainingDurationString != self.remainingDurationString {
                self.remainingDurationString = remainingDurationString
            }
        }
    }

    // The default duration formatter formats a duration in the range of X minutes through X minutes and 59 seconds as
    // "About X minutes remaining". Offset calculation to effectively change the range to X+1 minutes and 30 seconds through
    // X minutes and 29 seconds to address misleading messages when duration is two minutes down to complete.
    private let remainingDurationApproximationOffset: TimeInterval = 30

    private func remainingDurationToString(_ remainingDuration: TimeInterval) -> String? {
        switch remainingDuration {
        case 0..<15:
            return NSLocalizedString("A few seconds remaining", comment: "Estimated remaining duration with a few seconds")
        case 15..<60:
            return NSLocalizedString("Less than a minute remaining", comment: "Estimated remaining duration with less than a minute")
        default:
            guard let durationString = durationFormatter.string(from: remainingDuration + remainingDurationApproximationOffset) else {
                return nil
            }
            return String(format: NSLocalizedString("%@ remaining", comment: "Estimated remaining duration with more than a minute"), durationString)
        }
    }

    private var durationFormatter: DateComponentsFormatter { Self.durationFormatter }

    private var timestampFormatter: ISO8601DateFormatter { Self.timestampFormatter }

    private static var durationFormatter: DateComponentsFormatter = {
        let durationFormatter = DateComponentsFormatter()
        durationFormatter.allowedUnits = [.hour, .minute]
        durationFormatter.includesApproximationPhrase = true
        durationFormatter.unitsStyle = .full
        return durationFormatter
    }()

    private static let timestampFormatter: ISO8601DateFormatter = {
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.timeZone = calendar.timeZone
        timestampFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
        return timestampFormatter
    }()

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

class CriticalEventLogExportActivityItemSource: NSObject, UIActivityItemSource {
    private let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }

    // MARK: - UIActivityItemSource

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return url.lastPathComponent
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "com.pkware.zip-archive"
    }
}
