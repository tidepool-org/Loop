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

    static func generateDiagnosticReport(deviceManager: DeviceDataManager) -> T {
        let date = Date()
        let vc = T(command: { (completionHandler) in
            DispatchQueue.global(qos: .userInitiated).async {
                let group = DispatchGroup()
                
                var loopManagerReport: String?
                group.enter()
                deviceManager.loopManager.generateDiagnosticReport { (report) in
                    loopManagerReport = report
                    group.leave()
                }

                var deviceManagerReport: String?
                group.enter()
                deviceManager.generateDiagnosticReport { (report) in
                    deviceManagerReport = report
                    group.leave()
                }
                group.wait()

                DispatchQueue.main.async {
                    completionHandler([
                        "Use the Share button above save this diagnostic report to aid investigating your problem. Issues can be filed at https://github.com/LoopKit/Loop/issues.",
                        "Generated: \(date)",
                        "",
                        deviceManagerReport!,
                        "",
                        loopManagerReport!,
                        "",
                        ].joined(separator: "\n\n"))
                }
            }

            return NSLocalizedString("Loading...", comment: "The loading message for the diagnostic report screen")
        })
        vc.fileName = "Loop Report \(ISO8601DateFormatter.string(from: date, timeZone: .current, formatOptions: [.withSpaceBetweenDateAndTime, .withInternetDateTime])).md"

        return vc
    }
}
