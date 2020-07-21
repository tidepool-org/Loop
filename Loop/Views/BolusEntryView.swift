//
//  BolusEntryView.swift
//  Loop
//
//  Created by Michael Pangburn on 7/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import HealthKit
import SwiftUI
import LoopKit
import LoopKitUI
import LoopUI


struct PredictedGlucoseChartView: UIViewRepresentable {
    let chartManager: ChartsManager
    var glucoseUnit: HKUnit
    var glucoseValues: [GlucoseValue]
    var predictedGlucoseValues: [GlucoseValue]
    var targetGlucoseSchedule: GlucoseRangeSchedule?
    var preMealOverride: TemporaryScheduleOverride?
    var scheduleOverride: TemporaryScheduleOverride?
    var dateInterval: DateInterval

    @Binding var isInteractingWithChart: Bool

    func makeUIView(context: Context) -> ChartContainerView {
        let view = ChartContainerView()
        view.chartGenerator = { [chartManager] frame in
            chartManager.chart(atIndex: 0, frame: frame)?.view
        }

        let gestureRecognizer = UILongPressGestureRecognizer()
        gestureRecognizer.minimumPressDuration = 0.1
        gestureRecognizer.addTarget(context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        chartManager.gestureRecognizer = gestureRecognizer
        view.addGestureRecognizer(gestureRecognizer)

        return view
    }

    func updateUIView(_ chartContainerView: ChartContainerView, context: Context) {
        chartManager.invalidateChart(atIndex: 0)
        chartManager.startDate = dateInterval.start
        chartManager.maxEndDate = dateInterval.end
        chartManager.updateEndDate(dateInterval.end)
        predictedGlucoseChart.glucoseUnit = glucoseUnit
        predictedGlucoseChart.targetGlucoseSchedule = targetGlucoseSchedule
        predictedGlucoseChart.preMealOverride = preMealOverride
        predictedGlucoseChart.scheduleOverride = scheduleOverride
        predictedGlucoseChart.setGlucoseValues(glucoseValues)
        predictedGlucoseChart.setPredictedGlucoseValues(predictedGlucoseValues)
        chartManager.prerender()
        chartContainerView.reloadChart()
    }

    var predictedGlucoseChart: PredictedGlucoseChart {
        guard chartManager.charts.count == 1, let predictedGlucoseChart = chartManager.charts.first as? PredictedGlucoseChart else {
            fatalError("Expected exactly one predicted glucose chart in ChartsManager")
        }

        return predictedGlucoseChart
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator {
        var parent: PredictedGlucoseChartView

        init(_ parent: PredictedGlucoseChartView) {
            self.parent = parent
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            // FIXME: disappearance happens abruptly
            let animation = Animation
                .easeInOut(duration: parent.isInteractingWithChart ? 0.5 : 0.2)
                .delay(parent.isInteractingWithChart ? 1 : 0)

            switch recognizer.state {
            case .began:
                withAnimation(animation) {
                    parent.isInteractingWithChart = true
                }
            case .cancelled, .ended, .failed:
                withAnimation(animation) {
                    parent.isInteractingWithChart = false
                }
            default:
                break
            }
        }
    }
}


struct BolusEntryView: View, HorizontalSizeClassOverride {
    @ObservedObject var viewModel: BolusEntryViewModel

    @State private var enteredBolusAmount = ""
    @State private var isInteractingWithChart = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                historySection
                summarySection
            }
//            .keyboardAware()
            .listStyle(GroupedListStyle())
            .environment(\.horizontalSizeClass, horizontalOverride)

            actionArea
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarTitle(viewModel.potentialCarbEntry == nil ? Text("Bolus", comment: "Title for bolus entry screen") : Text("Meal Bolus", comment: "Title for bolus entry screen when also entering carbs"))
        .alert(item: $viewModel.activeAlert, content: alert(for:))
    }

    private var historySection: some View {
        Section {
            VStack(spacing: 8) {
                HStack {
                    activeCarbsLabel
                    Spacer()
                    activeInsulinLabel
                }

                VStack(spacing: 4) {
                    Text("Glucose", comment: "Title for predicted glucose chart on bolus screen")
                        .font(.subheadline)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(isInteractingWithChart ? 0 : 1)

                    predictedGlucoseChart
                }
                .frame(height: viewModel.glucoseChartHeight ?? 170)
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var activeCarbsLabel: some View {
        if viewModel.activeCarbs != nil {
            LabeledQuantity(
                label: Text("Active Carbs", comment: "Title describing quantity of still-absorbing carbohydrates"),
                quantity: viewModel.activeCarbs!,
                unit: .gram()
            )
        }
    }

    @ViewBuilder
    private var activeInsulinLabel: some View {
        if viewModel.activeInsulin != nil {
            LabeledQuantity(
                label: Text("Active Insulin", comment: "Title describing quantity of still-absorbing insulin"),
                quantity: viewModel.activeInsulin!,
                unit: .internationalUnit(),
                maxFractionDigits: 2
            )
        }
    }

    private var predictedGlucoseChart: some View {
        PredictedGlucoseChartView(
            chartManager: viewModel.chartManager,
            glucoseUnit: viewModel.glucoseUnit,
            glucoseValues: viewModel.glucoseValues,
            predictedGlucoseValues: viewModel.predictedGlucoseValues,
            targetGlucoseSchedule: viewModel.targetGlucoseSchedule,
            preMealOverride: viewModel.preMealOverride,
            scheduleOverride: viewModel.scheduleOverride,
            dateInterval: viewModel.chartDateInterval,
            isInteractingWithChart: $isInteractingWithChart
        )
        .padding(.horizontal, -4)
    }

    private var summarySection: some View {
        Section {
            VStack(spacing: 16) {
                Text("Bolus Summary", comment: "Title for card displaying carb entry and bolus recommendation")
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                potentialCarbEntryRow
            }
            recommendedBolusRow
            bolusEntryRow
        }
        .padding(.top, 8)
    }

    private static let absorptionTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.collapsesLargestUnit = true
        formatter.unitsStyle = .abbreviated
        formatter.allowsFractionalUnits = true
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()

    @ViewBuilder
    private var potentialCarbEntryRow: some View {
        if viewModel.carbEntryAndAbsorptionTimeString != nil {
            HStack {
                Text("Carb Entry", comment: "Label for carb entry row on bolus screen")

                Text(viewModel.carbEntryAndAbsorptionTimeString!)
                    .foregroundColor(Color(.COBTintColor))
                    .modifier(LabelBackground())

                Spacer()

                Text("\(DateFormatter.localizedString(from: viewModel.potentialCarbEntry!.startDate, dateStyle: .none, timeStyle: .short)) + \(Self.absorptionTimeFormatter.string(from: viewModel.potentialCarbEntry!.absorptionTime!)!)")
                    .foregroundColor(Color(.secondaryLabelColor))
            }
        }
    }

    private static let doseAmountFormatter: NumberFormatter = {
        let quantityFormatter = QuantityFormatter()
        quantityFormatter.setPreferredNumberFormatter(for: .internationalUnit())
        return quantityFormatter.numberFormatter
    }()

    private var recommendedBolusRow: some View {
        HStack {
            Text("Recommended Bolus", comment: "Label for recommended bolus row on bolus screen")
            Spacer()
            HStack(alignment: .firstTextBaseline) {
                Text(recommendedBolusString)
                    .font(.title)
                    .foregroundColor(viewModel.enteredBolus.doubleValue(for: .internationalUnit()) == 0 && viewModel.isBolusRecommended ? .accentColor : Color(.label))
                    .onTapGesture {
                        if self.viewModel.isBolusRecommended {
                            self.typedBolusEntry.wrappedValue = self.recommendedBolusString
                        }
                    }

                bolusUnitsLabel
            }
        }
    }

    private var recommendedBolusString: String {
        Self.doseAmountFormatter.string(from: viewModel.recommendedBolus?.doubleValue(for: .internationalUnit()) ?? 0)!
    }

    private var bolusEntryRow: some View {
        HStack {
            Text("Bolus", comment: "Label for bolus entry row on bolus screen")
            Spacer()
            HStack(alignment: .firstTextBaseline) {
                DismissibleKeyboardTextField(
                    text: typedBolusEntry,
                    placeholder: Self.doseAmountFormatter.string(from: 0.0)!,
                    font: .preferredFont(forTextStyle: .title1),
                    textColor: .systemBlue,
                    textAlignment: .right,
                    keyboardType: .decimalPad
                )
                
                bolusUnitsLabel
            }
        }
    }

    private var bolusUnitsLabel: some View {
        Text(QuantityFormatter().string(from: .internationalUnit()))
            .foregroundColor(Color(.secondaryLabelColor))
    }

    private var typedBolusEntry: Binding<String> {
        Binding(
            get: { self.enteredBolusAmount },
            set: { newValue in
                self.viewModel.enteredBolus = HKQuantity(unit: .internationalUnit(), doubleValue: Double(newValue) ?? 0)
                self.enteredBolusAmount = newValue
            }
        )
    }

    private var actionArea: some View {
        VStack(spacing: 0) {
            Text("Warning will go here")
                .padding([.top, .horizontal])
                .transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))

            Button(
                action: viewModel.saveCarbsAndDeliverBolus,
                label: {
                    if viewModel.enteredBolus.doubleValue(for: .internationalUnit()) == 0 {
                        Text("Save without Bolusing")
                    } else {
                        Text("Save and Deliver")
                    }
                }
            )
            .buttonStyle(ActionButtonStyle(.primary))
            .padding()
        }
        .padding(.bottom) // FIXME: unnecessary on iPhone 8 size devices
        .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
    }

    private func alert(for alert: BolusEntryViewModel.Alert) -> SwiftUI.Alert {
        switch alert {
        case .maxBolusExceeded:
            return SwiftUI.Alert(
                title: Text("Exceeds Maximum Bolus", comment: "The title of the alert describing a maximum bolus validation error"),
                message: Text("The maximum bolus amount is \(viewModel.maximumBolusAmountString) U", comment: "Body of the alert describing a maximum bolus validation error. (1: The localized max bolus value)")
            )
        }
    }
}

struct LabeledQuantity: View {
    var label: Text
    var quantity: HKQuantity
    var unit: HKUnit
    var maxFractionDigits: Int?

    var body: some View {
        HStack(spacing: 4) {
            label
                .bold()
            valueText
                .foregroundColor(Color(.secondaryLabelColor))
        }
        .font(.subheadline)
        .modifier(LabelBackground())
    }

    var valueText: Text {
        let formatter = QuantityFormatter()
        formatter.setPreferredNumberFormatter(for: unit)

        if let maxFractionDigits = maxFractionDigits {
            formatter.numberFormatter.maximumFractionDigits = maxFractionDigits
        }

        guard let string = formatter.string(from: quantity, for: unit) else {
            assertionFailure("Unable to format \(quantity) \(unit)")
            return Text("")
        }

        return Text(string)
    }
}

struct LabelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(.systemGray6))
            )
    }
}

