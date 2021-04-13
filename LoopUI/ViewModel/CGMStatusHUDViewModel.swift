//
//  CGMStatusHUDViewModel.swift
//  LoopUI
//
//  Created by Nathaniel Hamming on 2020-06-24.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit

public class CGMStatusHUDViewModel {
    
    static let staleGlucoseRepresentation: String = NSLocalizedString("– – –", comment: "No glucose value representation (3 dashes for mg/dL)")
    
    var trend: GlucoseTrend?
    
    var unitsString: String = "–"
    
    var glucoseValueString: String = CGMStatusHUDViewModel.staleGlucoseRepresentation
    
    var accessibilityString: String = ""
    
    var glucoseValueTintColor: UIColor = .label
    
    var glucoseTrendTintColor: UIColor = .glucoseTintColor
    
    var glucoseTrendIcon: UIImage? {
        guard let manualGlucoseTrendIconOverride = manualGlucoseTrendIconOverride else {
            return trend?.image ?? UIImage(systemName: "questionmark.circle")
        }
        return manualGlucoseTrendIconOverride
    }
    
    var manualGlucoseTrendIconOverride: UIImage?
    
    private var storedStatusHighlight: DeviceStatusHighlight?
    
    var statusHighlight: DeviceStatusHighlight? {
        get {
            guard manualGlucoseTrendIconOverride == nil else {
                // if there is an icon override for a manual glucose, don't provide the stored status highlight
                return nil
            }
            return storedStatusHighlight
        }
        set {
            storedStatusHighlight = newValue
            if manualGlucoseTrendIconOverride != nil {
                // If there is an icon override for a manual glucose, it displays the current status highlight icon
                setManualGlucoseTrendIconOverride()
            }
        }
    }
    
    var isVisible: Bool = true {
        didSet {
            if oldValue != isVisible {
                if !isVisible {
                    stalenessTimer?.invalidate()
                    stalenessTimer = nil
                } else {
                    startStalenessTimerIfNeeded()
                }
            }
        }
    }
    
    private var stalenessTimer: Timer?
    
    private var isStaleAt: Date? {
        didSet {
            if oldValue != isStaleAt {
                stalenessTimer?.invalidate()
                stalenessTimer = nil
            }
        }
    }
    
    private func startStalenessTimerIfNeeded() {
        if let fireDate = isStaleAt,
            isVisible,
            stalenessTimer == nil
        {
            stalenessTimer = Timer(fire: fireDate, interval: 0, repeats: false) { (_) in
                self.displayStaleGlucoseValue()
                self.staleGlucoseValueHandler()
            }
            RunLoop.main.add(stalenessTimer!, forMode: .default)
        }
    }
    
    private lazy var timeFormatter = DateFormatter(timeStyle: .short)
    
    var staleGlucoseValueHandler: () -> Void
    
    init(staleGlucoseValueHandler: @escaping () -> Void) {
        self.staleGlucoseValueHandler = staleGlucoseValueHandler
    }

    var lastCommunicationDate: Date? {
        didSet {
            if let signalLossHighlight = signalLossHighlight {
                statusHighlight = signalLossHighlight
            }
        }
    }

    private var staleGlucoseAge: TimeInterval?

    func setGlucoseQuantity(_ glucoseQuantity: Double,
                            at glucoseStartDate: Date,
                            unit: HKUnit,
                            staleGlucoseAge: TimeInterval,
                            glucoseDisplay: GlucoseDisplayable?,
                            wasUserEntered: Bool,
                            isDisplayOnly: Bool)
    {
        var accessibilityStrings = [String]()
        
        // reset state
        manualGlucoseTrendIconOverride = nil
        trend = nil
        
        let time = timeFormatter.string(from: glucoseStartDate)

        self.staleGlucoseAge = staleGlucoseAge
        isStaleAt = glucoseStartDate.addingTimeInterval(staleGlucoseAge)
        let glucoseValueCurrent = Date() < isStaleAt!
        
        glucoseValueTintColor = glucoseDisplay?.glucoseRangeCategory?.glucoseColor ?? .label
        
        let numberFormatter = NumberFormatter.glucoseFormatter(for: unit)
        if let valueString = numberFormatter.string(from: glucoseQuantity) {
            if glucoseValueCurrent {
                startStalenessTimerIfNeeded()
                switch glucoseDisplay?.glucoseRangeCategory {
                case .some(.belowRange):
                    glucoseValueString = LocalizedString("LOW", comment: "String displayed instead of a glucose value below the CGM range")
                case .some(.aboveRange):
                    glucoseValueString = LocalizedString("HIGH", comment: "String displayed instead of a glucose value above the CGM range")
                default:
                    glucoseValueString = valueString
                }
            } else {
                displayStaleGlucoseValue()
            }
            accessibilityStrings.append(String(format: LocalizedString("%1$@ at %2$@", comment: "Accessbility format value describing glucose: (1: glucose number)(2: glucose time)"), valueString, time))
        }

        // Only a user-entered glucose value that is *not* display-only (i.e. a calibration) is considered a manual glucose entry.
        let isManualGlucose = wasUserEntered && !isDisplayOnly
        if isManualGlucose, glucoseValueCurrent {
            // a manual glucose value presents any status highlight icon instead of a trend icon
            setManualGlucoseTrendIconOverride()
        } else if let trend = glucoseDisplay?.trendType, glucoseValueCurrent {
            self.trend = trend
            glucoseTrendTintColor = glucoseDisplay?.glucoseRangeCategory?.trendColor ?? .glucoseTintColor
            accessibilityStrings.append(trend.localizedDescription)
        } else {
            glucoseTrendTintColor = .glucoseTintColor
        }
                
        unitsString = unit.localizedShortUnitString
        accessibilityString = accessibilityStrings.joined(separator: ", ")
    }

    func displayStaleGlucoseValue() {
        glucoseValueString = CGMStatusHUDViewModel.staleGlucoseRepresentation
        glucoseValueTintColor = .label
        trend = nil
        glucoseTrendTintColor = .glucoseTintColor
        manualGlucoseTrendIconOverride = nil
        if let signalLossHighlight = signalLossHighlight {
            statusHighlight = signalLossHighlight
        }
    }
    
    func setManualGlucoseTrendIconOverride() {
        manualGlucoseTrendIconOverride = storedStatusHighlight?.image ?? UIImage(systemName: "questionmark.circle")
        glucoseTrendTintColor = storedStatusHighlight?.state.color ?? .glucoseTintColor
    }
}

fileprivate extension CGMStatusHUDViewModel {
    struct Highlight: DeviceStatusHighlight {
        var localizedMessage: String
        var imageName: String = "exclamationmark.circle.fill"
        var state: DeviceStatusHighlightState = .critical

        init(localizedMessage: String) {
            self.localizedMessage = localizedMessage
        }
    }

    var signalLossHighlight: DeviceStatusHighlight? {
        guard let lastCommunicationDate = lastCommunicationDate,
              let staleGlucoseAge = staleGlucoseAge,
              -lastCommunicationDate.timeIntervalSinceNow > staleGlucoseAge else
        {
            // device has sent communications recently, so there is no signal loss
            return nil
        }

        return Highlight(localizedMessage: NSLocalizedString("Signal Loss", comment: "Message to the user to that a CGM signal has been loss"))
    }
}
