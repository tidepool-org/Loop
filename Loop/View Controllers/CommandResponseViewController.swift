//
//  CommandResponseViewController.swift
//  Loop
//
//  Created by Nate Racklyeft on 9/30/16.
//  Copyright © 2016 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKitUI


extension CommandResponseViewController {
    typealias T = CommandResponseViewController

    static func generateDiagnosticReport(reportGenerator: DiagnosticReportGenerator) -> T {
        let date = Date()
        let vc = T(command: { (completionHandler) in
            Task { @MainActor in
                let report = await reportGenerator.generateDiagnosticReport()
                // TODO: https://tidepool.atlassian.net/browse/LOOP-4771
                completionHandler([
                    "Use the Share button above to save this diagnostic report to aid investigating your problem. Issues can be filed at https://github.com/LoopKit/Loop/issues.",
                    "Generated: \(date)",
                    "",
                    report,
                    "",
                ].joined(separator: "\n\n"))
            }
            return NSLocalizedString("Loading...", comment: "The loading message for the diagnostic report screen")
        })
        vc.fileName = "Loop Report \(ISO8601DateFormatter.string(from: date, timeZone: .current, formatOptions: [.withSpaceBetweenDateAndTime, .withInternetDateTime])).md"

        return vc
    }
}
