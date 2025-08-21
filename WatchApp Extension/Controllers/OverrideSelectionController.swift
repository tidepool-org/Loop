//
//  OverrideSelectionController.swift
//  WatchApp Extension
//
//  Created by Michael Pangburn on 1/31/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import WatchKit
import LoopKit
import LoopCore
import WatchConnectivity


protocol OverrideSelectionControllerDelegate: AnyObject {
    func overrideSelectionController(_ controller: OverrideSelectionController, didSelectPreset preset: TemporaryPreset)
}


final class OverrideSelectionController: WKInterfaceController, IdentifiableClass {

    @IBOutlet private var table: WKInterfaceTable!

    private let loopManager = ExtensionDelegate.shared().loopManager
    private lazy var presets = loopManager.watchInfo.loopSettings.overridePresets

    weak var delegate: OverrideSelectionControllerDelegate?
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        delegate = context as? OverrideSelectionControllerDelegate

        guard !presets.isEmpty else {
            assertionFailure("Instantiating override selection controller without configured presets")
            return
        }

        configureTable()
    }

    private func configureTable() {
        table.setRowTypes([OverridePresetRow.className])
        table.setNumberOfRows(presets.count, withRowType: OverridePresetRow.className)
        for index in presets.indices {
            let row = table.rowController(at: index) as! OverridePresetRow
            let preset = presets[index]
            if let symbol = preset.symbol?.textualRepresentation {
                row.symbolLabel.setText(symbol)
                row.symbolLabel.setHidden(false)
            } else {
                row.symbolLabel.setHidden(true)
            }
            row.nameLabel.setText(preset.name)
        }
    }

    override func willActivate() {
        super.willActivate()
    }

    override func didDeactivate() {
        super.didDeactivate()
    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        let preset = presets[rowIndex]
        delegate?.overrideSelectionController(self, didSelectPreset: preset)
        dismiss()
    }
}
