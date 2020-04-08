//
//  CarbAndBolusFlowController.swift
//  WatchApp Extension
//
//  Created by Michael Pangburn on 4/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import WatchKit
import SwiftUI
import HealthKit
import LoopCore
import LoopKit


final class CarbAndBolusFlowController: WKHostingController<CarbAndBolusFlow>, IdentifiableClass {
    private var viewModel: CarbAndBolusFlowViewModel {
        CarbAndBolusFlowViewModel(
            configuration: configuration,
            presentAlert: { [unowned self] title, message in
                self.presentAlert(withTitle: title, message: message, preferredStyle: .alert, actions: [.dismissAction()])
            },
            dismiss: { [unowned self] in
                self.willDeactivateObserver = nil
                self.dismiss()
            }
        )
    }

    private var configuration: CarbAndBolusFlow.Configuration = .carbEntry

    override var body: CarbAndBolusFlow {
        CarbAndBolusFlow(viewModel: viewModel)
    }

    private var willDeactivateObserver: AnyObject? {
        didSet {
            if let oldValue = oldValue {
                NotificationCenter.default.removeObserver(oldValue)
            }
        }
    }

    override func awake(withContext context: Any?) {
        if let configuration = context as? CarbAndBolusFlow.Configuration {
            self.configuration = configuration
        }
    }

    override func didAppear() {
        super.didAppear()

        updateNewCarbEntryUserActivity()

        // If the screen turns off, the screen should be dismissed for safety reasons
        willDeactivateObserver = NotificationCenter.default.addObserver(forName: ExtensionDelegate.willResignActiveNotification, object: ExtensionDelegate.shared(), queue: nil, using: { [weak self] (_) in
            if let self = self {
                WKInterfaceDevice.current().play(.failure)
                self.dismiss()
            }
        })
    }

    override func didDeactivate() {
        super.didDeactivate()

        willDeactivateObserver = nil
    }
}

extension CarbAndBolusFlowController: NSUserActivityDelegate {
    private var defaultCarbEntry: NewCarbEntry {
        let absorptionTime = LoopSettings.defaultCarbAbsorptionTimes.medium
        return NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: nil, absorptionTime: absorptionTime, syncIdentifier: UUID().uuidString)
    }

    func updateNewCarbEntryUserActivity() {
        if #available(watchOSApplicationExtension 5.0, *) {
            let userActivity = NSUserActivity.forDidAddCarbEntryOnWatch()
            update(userActivity)
        } else {
            let userActivity = NSUserActivity.forNewCarbEntry()
            userActivity.update(from: defaultCarbEntry)
            updateUserActivity(userActivity.activityType, userInfo: userActivity.userInfo, webpageURL: nil)
        }
    }
}
