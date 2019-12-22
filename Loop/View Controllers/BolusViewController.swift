//
//  BolusViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/11/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import LocalAuthentication
import LoopKit
import LoopKitUI
import HealthKit
import LoopCore
import LoopUI


private extension RefreshContext {
    static let all: Set<RefreshContext> = [.glucose, .targets]
}

final class BolusViewController: ChartsTableViewController, IdentifiableClass, UITextFieldDelegate {
    private enum Section: Int {
        case bolusInfo
        case deliver
    }

    private enum BolusInfoRow: Int {
        case chart = 0
        case notice
        case active
        case recommended
        case entry
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // This gets rid of the empty space at the top.
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 0.01))

        glucoseChart.glucoseDisplayRange = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 60)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200)

        let notificationCenter = NotificationCenter.default

        notificationObservers += [
            notificationCenter.addObserver(forName: .LoopDataUpdated, object: deviceManager.loopManager, queue: nil) { [weak self] note in
                let context = note.userInfo?[LoopDataManager.LoopUpdateContextKey] as! LoopDataManager.LoopUpdateContext.RawValue
                DispatchQueue.main.async {
                    switch LoopDataManager.LoopUpdateContext(rawValue: context) {
                    case .preferences?:
                        self?.refreshContext.formUnion([.status, .targets])
                    case .glucose?:
                        self?.refreshContext.update(with: .glucose)
                    default:
                        break
                    }

                    self?.reloadData(animated: true)
                }
            }
        ]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let spellOutFormatter = NumberFormatter()
        spellOutFormatter.numberStyle = .spellOut

        let amount = bolusRecommendation?.amount ?? 0
        bolusAmountTextField.accessibilityHint = String(format: NSLocalizedString("Recommended Bolus: %@ Units", comment: "Accessibility hint describing recommended bolus units"), spellOutFormatter.string(from: amount) ?? "0")

        bolusAmountTextField.becomeFirstResponder()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

        if !visible {
            refreshContext = RefreshContext.all
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        refreshContext.update(with: .size(size))

        super.viewWillTransition(to: size, with: coordinator)
    }

    func generateActiveInsulinDescription(activeInsulin: Double?, pendingInsulin: Double?) -> String
    {
        let iobStr: String
        if let iob = activeInsulin, let valueStr = insulinFormatter.string(from: iob)
        {
            iobStr = valueStr + " U"
        } else {
            iobStr = "-"
        }

        var rval = String(format: NSLocalizedString("Active Insulin: %@", comment: "The string format describing active insulin. (1: localized insulin value description)"), iobStr)

        if let pending = pendingInsulin, pending > 0, let pendingStr = insulinFormatter.string(from: pending)
        {
            rval += String(format: NSLocalizedString(" (pending: %@)", comment: "The string format appended to active insulin that describes pending insulin. (1: pending insulin)"), pendingStr + " U")
        }
        return rval
    }

    // MARK: - State

    var glucoseUnit: HKUnit = .milligramsPerDeciliter

    var bolusRecommendation: BolusRecommendation? = nil {
        didSet {
            let amount = bolusRecommendation?.amount ?? 0
            recommendedBolusAmountLabel?.text = bolusUnitsFormatter.string(from: amount)
            updateNotice()
            if let pendingInsulin = bolusRecommendation?.pendingInsulin {
                self.pendingInsulin = pendingInsulin
            }
        }
    }

    var activeCarbohydratesDescription: String? = nil {
        didSet {
            activeCarbohydratesLabel?.text = activeCarbohydratesDescription
        }
    }

    var activeCarbohydrates: Double? = nil {
        didSet {

            let cobStr: String
            if let cob = activeCarbohydrates, let str = integerFormatter.string(from: cob) {
                cobStr = str + " g"
            } else {
                cobStr = "-"

            }
            activeCarbohydratesDescription = String(format: NSLocalizedString("Active Carbohydrates: %@", comment: "The string format describing active carbohydrates. (1: localized glucose value description)"), cobStr)
        }
    }

    var activeInsulinDescription: String? = nil {
        didSet {
            activeInsulinLabel?.text = activeInsulinDescription
        }
    }

    var activeInsulin: Double? = nil {
        didSet {
            activeInsulinDescription = generateActiveInsulinDescription(activeInsulin: activeInsulin, pendingInsulin: pendingInsulin)
        }
    }

    var pendingInsulin: Double? = nil {
        didSet {
            activeInsulinDescription = generateActiveInsulinDescription(activeInsulin: activeInsulin, pendingInsulin: pendingInsulin)
        }
    }


    var maxBolus: Double = 25

    private(set) var bolus: Double?

    private var refreshContext = RefreshContext.all

    private let glucoseChart = PredictedGlucoseChart()

    private var chartStartDate: Date {
        get { charts.startDate }
        set {
            if newValue != chartStartDate {
                refreshContext = RefreshContext.all
            }

            charts.startDate = newValue
        }
    }

    private var eventualGlucoseDescription: String?

    override func createChartsManager() -> ChartsManager {
        ChartsManager(colors: .default, settings: .default, charts: [glucoseChart], traitCollection: traitCollection)
    }

    override func glucoseUnitDidChange() {
        refreshContext = RefreshContext.all
    }

    override func reloadData(animated: Bool = false) {
        guard active && visible && !refreshContext.isEmpty else { return }

        refreshContext.remove(.size(.zero))
        let calendar = Calendar.current
        var components = DateComponents()
        components.minute = 0
        let date = Date(timeIntervalSinceNow: -TimeInterval(hours: 1))
        chartStartDate = calendar.nextDate(after: date, matching: components, matchingPolicy: .strict, direction: .backward) ?? date

        let reloadGroup = DispatchGroup()
        if self.refreshContext.remove(.glucose) != nil {
            reloadGroup.enter()
            self.deviceManager.loopManager.glucoseStore.getCachedGlucoseSamples(start: self.chartStartDate) { (values) -> Void in
                self.glucoseChart.setGlucoseValues(values)
                reloadGroup.leave()
            }
        }

        // For now, do this every time
        _ = self.refreshContext.remove(.status)
        reloadGroup.enter()
        self.deviceManager.loopManager.getLoopState { (manager, state) in
            do {
                let glucose = try state.predictGlucose(using: .all, potentialBolus: self.enteredBolus)
                self.glucoseChart.setPredictedGlucoseValues(glucose)
            } catch {
                self.refreshContext.update(with: .status)
                self.glucoseChart.setPredictedGlucoseValues([])
            }

            if let lastPoint = self.glucoseChart.predictedGlucosePoints.last?.y {
                self.eventualGlucoseDescription = String(describing: lastPoint)
            } else {
                self.eventualGlucoseDescription = nil
            }

            if self.refreshContext.remove(.targets) != nil {
                self.glucoseChart.targetGlucoseSchedule = manager.settings.glucoseTargetRangeSchedule
                self.glucoseChart.scheduleOverride = manager.settings.scheduleOverride
            }

            reloadGroup.leave()
        }

        reloadGroup.notify(queue: .main) {
            self.reloadChart()
        }
    }

    private func reloadChart() {
        charts.invalidateChart(atIndex: 0)
        charts.prerender()

        tableView.beginUpdates()
        for case let cell as ChartTableViewCell in tableView.visibleCells {
            cell.reloadChart()

            if let indexPath = tableView.indexPath(for: cell) {
                self.tableView(tableView, updateSubtitleFor: cell, at: indexPath)
            }
        }
        tableView.endUpdates()
    }

    // MARK: - IBOutlets

    @IBOutlet weak var recommendedBolusAmountLabel: UILabel? {
        didSet {
            let amount = bolusRecommendation?.amount ?? 0
            recommendedBolusAmountLabel?.text = bolusUnitsFormatter.string(from: amount)
        }
    }

    @IBOutlet weak var noticeLabel: UILabel? {
        didSet {
            updateNotice()
        }
    }

    @IBOutlet weak var activeCarbohydratesLabel: UILabel? {
        didSet {
            activeCarbohydratesLabel?.text = activeCarbohydratesDescription
        }
    }

    @IBOutlet weak var activeInsulinLabel: UILabel? {
        didSet {
            activeInsulinLabel?.text = activeInsulinDescription
        }
    }

    // MARK: - TableView Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if case .recommended? = BolusInfoRow(rawValue: indexPath.row) {
            acceptRecommendedBolus()
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) == .bolusInfo else {
            return
        }

        let row = BolusInfoRow(rawValue: indexPath.row)
        switch row {
        case .chart:
            let cell = cell as! ChartTableViewCell
            cell.contentView.layoutMargins.left = tableView.separatorInset.left
            cell.chartContentView.chartGenerator = { [weak self] (frame) in
                return self?.charts.chart(atIndex: 0, frame: frame)?.view
            }

            cell.titleLabel?.text = NSLocalizedString("Carb & Bolus Forecast", comment: "Title text for glucose prediction chart on bolus screen")
            cell.subtitleLabel?.textColor = UIColor.secondaryLabelColor
            self.tableView(tableView, updateSubtitleFor: cell, at: indexPath)
            cell.selectionStyle = .none

            cell.addGestureRecognizer(charts.gestureRecognizer!)
        case .recommended:
            cell.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: NSLocalizedString("AcceptRecommendedBolus", comment: "Action to copy the recommended Bolus value to the actual Bolus Field"), target: self, selector: #selector(BolusViewController.acceptRecommendedBolus))
            ]
        default:
            break
        }
    }

    private func tableView(_ tableView: UITableView, updateSubtitleFor cell: ChartTableViewCell, at indexPath: IndexPath) {
        assert(Section(rawValue: indexPath.row) == .bolusInfo && BolusInfoRow(rawValue: indexPath.row) == .chart)

        if let eventualGlucose = eventualGlucoseDescription {
            cell.subtitleLabel?.text = String(format: NSLocalizedString("Eventually %@", comment: "The subtitle format describing eventual glucose. (1: localized glucose value description)"), eventualGlucose)
        } else {
            cell.subtitleLabel?.text = SettingsTableViewCell.NoValueString
        }
    }

    @objc func acceptRecommendedBolus() {
        bolusAmountTextField?.text = recommendedBolusAmountLabel?.text
        bolusAmountChanged()
    }
    
    @IBOutlet weak var bolusAmountTextField: UITextField! {
        didSet {
            bolusAmountTextField.addTarget(self, action: #selector(bolusAmountChanged), for: .editingChanged)
        }
    }

    private var enteredBolusAmount: Double? {
        return DispatchQueue.main.sync {
            guard let text = bolusAmountTextField?.text, let amount = bolusUnitsFormatter.number(from: text)?.doubleValue else {
                return nil
            }

            return amount >= 0 ? amount : nil
        }
    }

    private var enteredBolus: DoseEntry? {
        guard let amount = enteredBolusAmount else {
            return nil
        }

        return DoseEntry(type: .bolus, startDate: Date(), value: amount, unit: .units)
    }

    private var predictionRecomputation: DispatchWorkItem?

    @objc private func bolusAmountChanged() {
        predictionRecomputation?.cancel()
        let predictionRecomputation = DispatchWorkItem(block: recomputePrediction)
        self.predictionRecomputation = predictionRecomputation
        let recomputeDelayMS = 300
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(recomputeDelayMS), execute: predictionRecomputation)
    }

    private func recomputePrediction() {
        deviceManager.loopManager.getLoopState { manager, state in
            if let prediction = try? state.predictGlucose(using: .all, potentialBolus: self.enteredBolus) {
                self.glucoseChart.setPredictedGlucoseValues(prediction)

                if let lastPoint = self.glucoseChart.predictedGlucosePoints.last?.y {
                    self.eventualGlucoseDescription = String(describing: lastPoint)
                } else {
                    self.eventualGlucoseDescription = nil
                }

                DispatchQueue.main.async {
                    self.reloadChart()
                }
            }
        }
    }

    // MARK: - Actions
   
    @IBAction func authenticateBolus(_ sender: Any) {
        bolusAmountTextField.resignFirstResponder()

        guard let text = bolusAmountTextField?.text, let bolus = bolusUnitsFormatter.number(from: text)?.doubleValue,
            let amountString = bolusUnitsFormatter.string(from: bolus) else {
            return
        }

        guard bolus <= maxBolus else {
            let alert = UIAlertController(
                title: NSLocalizedString("Exceeds Maximum Bolus", comment: "The title of the alert describing a maximum bolus validation error"),
                message: String(format: NSLocalizedString("The maximum bolus amount is %@ Units", comment: "Body of the alert describing a maximum bolus validation error. (1: The localized max bolus value)"), bolusUnitsFormatter.string(from: maxBolus) ?? ""),
                preferredStyle: .alert)

            let action = UIAlertAction(title: NSLocalizedString("com.loudnate.LoopKit.errorAlertActionTitle", value: "OK", comment: "The title of the action used to dismiss an error alert"), style: .default)
            alert.addAction(action)
            alert.preferredAction = action

            present(alert, animated: true)
            return
        }

        let context = LAContext()

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            context.evaluatePolicy(.deviceOwnerAuthentication,
                                   localizedReason: String(format: NSLocalizedString("Authenticate to Bolus %@ Units", comment: "The message displayed during a device authentication prompt for bolus specification"), amountString),
                                   reply: { (success, error) in
                if success {
                    DispatchQueue.main.async {
                        self.setBolusAndClose(bolus)
                    }
                }
            })
        } else {
            setBolusAndClose(bolus)
        }
    }

    private func setBolusAndClose(_ bolus: Double) {
        self.bolus = bolus

        self.performSegue(withIdentifier: "close", sender: nil)
    }

    private lazy var bolusUnitsFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()

        numberFormatter.maximumSignificantDigits = 3
        numberFormatter.minimumFractionDigits = 1

        return numberFormatter
    }()


    private lazy var insulinFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()

        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2

        return numberFormatter
    }()

    private lazy var integerFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()

        numberFormatter.numberStyle = .none
        numberFormatter.maximumFractionDigits = 0

        return numberFormatter
    }()

    private func updateNotice() {
        if let notice = bolusRecommendation?.notice {
            noticeLabel?.text = "⚠ \(notice.description(using: glucoseUnit))"
        } else {
            noticeLabel?.text = nil
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        bolusAmountTextField.resignFirstResponder()
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return true
    }
}
