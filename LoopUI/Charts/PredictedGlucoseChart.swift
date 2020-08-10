//
//  PredictedGlucoseChart.swift
//  LoopUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import LoopKitUI
import SwiftCharts
import HealthKit

public class PredictedGlucoseChart: GlucoseChart, ChartProviding {

    public private(set) var glucosePoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = glucosePoints.last?.x as? ChartAxisValueDate {
                updateEndDate(lastDate.date)
            }
        }
    }

    /// The chart points for predicted glucose
    public private(set) var predictedGlucosePoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = predictedGlucosePoints.last?.x as? ChartAxisValueDate {
                updateEndDate(lastDate.date)
            }
        }
    }

    /// The chart points for alternate predicted glucose
    public private(set) var alternatePredictedGlucosePoints: [ChartPoint]?

    public var targetGlucoseSchedule: GlucoseRangeSchedule? {
        didSet {
            targetGlucosePoints = []
        }
    }

    public var preMealOverride: TemporaryScheduleOverride? {
        didSet {
            preMealOverridePoints = []
            preMealOverrideDurationPoints = []
        }
    }

    public var scheduleOverride: TemporaryScheduleOverride? {
        didSet {
            targetOverridePoints = []
            targetOverrideDurationPoints = []
        }
    }

    private var targetGlucosePoints: [ChartPoint] = []

    private var preMealOverridePoints: [ChartPoint] = []

    private var preMealOverrideDurationPoints: [ChartPoint] = []

    private var targetOverridePoints: [ChartPoint] = []

    private var targetOverrideDurationPoints: [ChartPoint] = []

    private var glucoseChartCache: ChartPointsTouchHighlightLayerViewCache?

    public private(set) var endDate: Date?

    private var predictedGlucoseSuggestedBounds: (minimum: HKQuantity, maximum: HKQuantity)? = nil

    private func updateEndDate(_ date: Date) {
        if endDate == nil || date > endDate! {
            self.endDate = date
        }
    }
    
    public init(predictedGlucoseBounds: (minimum: HKQuantity, maximum: HKQuantity)? = (HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 40), HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 400))) {
        if let predictedGlucoseBounds = predictedGlucoseBounds {
            self.predictedGlucoseSuggestedBounds = predictedGlucoseBounds
        }
        super.init()
    }
}

extension PredictedGlucoseChart {
    public func didReceiveMemoryWarning() {
        glucosePoints = []
        predictedGlucosePoints = []
        alternatePredictedGlucosePoints = nil
        targetGlucosePoints = []
        targetOverridePoints = []
        targetOverrideDurationPoints = []

        glucoseChartCache = nil
    }

    public func generate(withFrame frame: CGRect, xAxisModel: ChartAxisModel, xAxisValues: [ChartAxisValue], axisLabelSettings: ChartLabelSettings, guideLinesLayerSettings: ChartGuideLinesLayerSettings, colors: ChartColorPalette, chartSettings: ChartSettings, labelsWidthY: CGFloat, gestureRecognizer: UIGestureRecognizer?, traitCollection: UITraitCollection) -> Chart
    {
        if targetGlucosePoints.isEmpty, xAxisValues.count > 1, let schedule = targetGlucoseSchedule {
            targetGlucosePoints = ChartPoint.pointsForGlucoseRangeSchedule(schedule, unit: glucoseUnit, xAxisValues: xAxisValues)

            var displayedScheduleOverride = scheduleOverride
            if let preMealOverride = preMealOverride, preMealOverride.isActive() {
                preMealOverridePoints = ChartPoint.pointsForGlucoseRangeScheduleOverride(preMealOverride, unit: glucoseUnit, xAxisValues: xAxisValues, extendEndDateToChart: true)
                preMealOverrideDurationPoints = ChartPoint.pointsForGlucoseRangeScheduleOverride(preMealOverride, unit: glucoseUnit, xAxisValues: xAxisValues)

                if displayedScheduleOverride != nil {
                    if displayedScheduleOverride!.endDate > preMealOverride.endDate {
                        displayedScheduleOverride!.activeInterval = DateInterval(start: preMealOverride.endDate, end: displayedScheduleOverride!.endDate)
                    } else {
                        displayedScheduleOverride = nil
                    }
                }
            } else {
                preMealOverridePoints = []
                preMealOverrideDurationPoints = []
            }

            if let override = displayedScheduleOverride, override.isActive() || override.startDate > Date() {
                targetOverridePoints = ChartPoint.pointsForGlucoseRangeScheduleOverride(override, unit: glucoseUnit, xAxisValues: xAxisValues, extendEndDateToChart: true)
                targetOverrideDurationPoints = ChartPoint.pointsForGlucoseRangeScheduleOverride(override, unit: glucoseUnit, xAxisValues: xAxisValues)
            } else {
                targetOverridePoints = []
                targetOverrideDurationPoints = []
            }
        }

        let points = [
            glucosePoints, predictedGlucosePoints,
            preMealOverridePoints, preMealOverrideDurationPoints,
            targetGlucosePoints, targetOverridePoints,
            glucoseDisplayRangePoints
        ].flatMap { $0 }

        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesWithChartPoints(points,
            minSegmentCount: 2,
            maxSegmentCount: 4,
            multiple: glucoseUnit.chartableIncrement * 25,
            axisValueGenerator: {
                ChartAxisValueDouble($0, labelSettings: axisLabelSettings)
            },
            addPaddingSegmentIfEdge: false
        )

        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(labelsWidthY))

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)

        // The glucose targets
        let targetFillAlpha: CGFloat = preMealOverridePoints.count > 1 || targetOverridePoints.count > 1 ? 0.15 : 0.3
        var fills: [ChartPointsFill?] = [
            ChartPointsFill(
                chartPoints: targetGlucosePoints,
                fillColor: colors.glucoseTint.withAlphaComponent(targetFillAlpha),
                createContainerPoints: false
            ),
            ChartPointsFill(
                chartPoints: preMealOverridePoints,
                fillColor: colors.glucoseTint.withAlphaComponent(0.3),
                createContainerPoints: false
            ),
            ChartPointsFill(
                chartPoints: preMealOverrideDurationPoints,
                fillColor: colors.glucoseTint.withAlphaComponent(0.3),
                createContainerPoints: false
            ),
            ChartPointsFill(
                chartPoints: targetOverrideDurationPoints,
                fillColor: colors.glucoseTint.withAlphaComponent(0.3),
                createContainerPoints: false
            )
        ]

        if preMealOverridePoints.isEmpty {
            fills.append(
                ChartPointsFill(
                    chartPoints: targetOverridePoints,
                    fillColor: colors.glucoseTint.withAlphaComponent(0.3),
                    createContainerPoints: false
                )
            )
        }

        let targetsLayer = ChartPointsFillsLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            fills: fills
        )

        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: guideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)

        let circles = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: glucosePoints, displayDelay: 0, itemSize: CGSize(width: 4, height: 4), itemFillColor: colors.glucoseTint, optimized: true)

        var alternatePrediction: ChartLayer?

        if let altPoints = alternatePredictedGlucosePoints, altPoints.count > 1 {

            let lineModel = ChartLineModel.predictionLine(points: altPoints, color: colors.glucoseTint, width: 2)

            alternatePrediction = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [lineModel])
        }

        var prediction: ChartLayer?

        if predictedGlucosePoints.count > 1 {
            let lineColor = (alternatePrediction == nil) ? colors.glucoseTint : UIColor.secondaryLabel

            let lineModel = ChartLineModel.predictionLine(
                points: predictedGlucosePoints,
                color: lineColor,
                width: 1
            )

            prediction = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [lineModel])
        }

        if gestureRecognizer != nil {
            glucoseChartCache = ChartPointsTouchHighlightLayerViewCache(
                xAxisLayer: xAxisLayer,
                yAxisLayer: yAxisLayer,
                axisLabelSettings: axisLabelSettings,
                chartPoints: glucosePoints + (alternatePredictedGlucosePoints ?? predictedGlucosePoints),
                tintColor: colors.glucoseTint,
                gestureRecognizer: gestureRecognizer
            )
        }

        let layers: [ChartLayer?] = [
            gridLayer,
            targetsLayer,
            xAxisLayer,
            yAxisLayer,
            glucoseChartCache?.highlightLayer,
            prediction,
            alternatePrediction,
            circles
        ]

        return Chart(
            frame: frame,
            innerFrame: innerFrame,
            settings: chartSettings,
            layers: layers.compactMap { $0 }
        )
    }
}

extension PredictedGlucoseChart {
    public func setGlucoseValues(_ glucoseValues: [GlucoseValue]) {
        glucosePoints = glucosePointsFromValues(glucoseValues)
    }

    public func setPredictedGlucoseValues(_ glucoseValues: [GlucoseValue]) {
        let clampedPredicatedGlucoseValues = clampPredictedGlucoseValues(glucoseValues)
        predictedGlucosePoints = glucosePointsFromValues(clampedPredicatedGlucoseValues)
    }

    public func setAlternatePredictedGlucoseValues(_ glucoseValues: [GlucoseValue]) {
        alternatePredictedGlucosePoints = glucosePointsFromValues(glucoseValues)
    }
}


// MARK: - Clamping the predicted glucose values
extension PredictedGlucoseChart {
    var glucoseValueMaximum: HKQuantity? {
        guard let glucosePointMaximum = glucosePoints.max(by: { point1, point2 in point1.y.scalar < point2.y.scalar }) else {
            return nil
        }
        return HKQuantity(unit: glucoseUnit, doubleValue: glucosePointMaximum.y.scalar)
    }
    
    var glucoseValueMinimum: HKQuantity? {
        guard let glucosePointMinimum = glucosePoints.min(by: { point1, point2 in point1.y.scalar < point2.y.scalar }) else {
            return nil
        }
        return HKQuantity(unit: glucoseUnit, doubleValue: glucosePointMinimum.y.scalar)
    }
    
    func clampPredictedGlucoseValues(_ glucoseValues: [GlucoseValue]) -> [GlucoseValue] {
        guard let predictedGlucoseBounds = predictedGlucoseSuggestedBounds else {
            return glucoseValues
        }
        
        let predictedGlucoseValueMaximum = glucoseValueMaximum != nil ? max(predictedGlucoseBounds.maximum, glucoseValueMaximum!) : predictedGlucoseBounds.maximum
        
        let predictedGlucoseValueMinimum = glucoseValueMinimum != nil ? min(predictedGlucoseBounds.minimum, glucoseValueMinimum!) : predictedGlucoseBounds.minimum
        
        return glucoseValues.map {
            if $0.quantity > predictedGlucoseValueMaximum {
                return PredictedGlucoseValue(startDate: $0.startDate, quantity: predictedGlucoseValueMaximum)
            } else if $0.quantity < predictedGlucoseValueMinimum {
                return PredictedGlucoseValue(startDate: $0.startDate, quantity: predictedGlucoseValueMinimum)
            } else {
                return $0
            }
        }
    }
}
