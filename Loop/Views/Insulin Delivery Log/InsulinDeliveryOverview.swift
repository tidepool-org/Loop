//
//  InsulinDeliveryOverview.swift
//  Loop
//
//  Created by Cameron Ingham on 3/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import SwiftUI

struct DatedQuantity: Hashable {
    let date: Date
    let quantity: LoopQuantity
}

struct InsulinDeliveryOverview: View {
    enum State: Hashable {
        enum AutomatedBasalStatus: Hashable {
            case scheduled
            case moreThanScheduled
            case lessThanScheduled
        }
        
        case automationOn(basalStatus: AutomatedBasalStatus)

        case automationOff
        
        enum ErrorStatus: Hashable {
            case noDelivery
            case suspended
        }
        
        case error(status: ErrorStatus)
    }
    
    @Environment(\.colorPalette) private var colorPalette
    
    @ScaledMetric private var iconSize: Double = 26
    
    private let rateFormatter = QuantityFormatter(for: .internationalUnitsPerHour)
    private let bolusFormatter = QuantityFormatter(for: .internationalUnit)

    private let state: State
    private let time: Date
    private let currentBasalRate: DatedQuantity
    private let lastAutoBolus: DatedQuantity?
    
    init(state: State, time: Date, currentBasalRate: DatedQuantity, lastAutoBolus: DatedQuantity?) {
        self.state = state
        self.time = time
        self.currentBasalRate = currentBasalRate
        self.lastAutoBolus = lastAutoBolus
    }

    @ViewBuilder
    var icon: some View {
        VStack {
            switch state {
            case .automationOn(let basalStatus):
                VStack {
                    switch basalStatus {
                    case .scheduled:
                        Text(Image(systemName: "arrow.right.square.fill"))
                    case .moreThanScheduled:
                        Text(Image(systemName: "arrow.up.square.fill"))
                    case .lessThanScheduled:
                        Text(Image(systemName: "arrow.down.square.fill"))
                    }
                }
                .foregroundStyle(Color.accentColor)
            case .automationOff:
                Text(Image(systemName: "arrow.right.square.fill"))
                    .foregroundStyle(Color.accentColor)
            case .error(let status):
                VStack {
                    switch status {
                    case .noDelivery:
                        Text(Image(systemName: "xmark.circle.fill"))
                            .foregroundStyle(colorPalette.guidanceColors.critical)
                    case .suspended:
                        Text(Image(systemName: "pause.circle.fill"))
                            .foregroundStyle(colorPalette.guidanceColors.warning)
                    }
                }
            }
        }
        .font(.system(size: iconSize))
    }
    
    var statusTitle: Text {
        switch state {
        case .automationOn(let basalStatus):
            switch basalStatus {
            case .scheduled:
                Text("Scheduled basal")
            case .moreThanScheduled:
                Text("More than scheduled")
            case .lessThanScheduled:
                Text("Less than scheduled")
            }
        case .automationOff:
            Text("Scheduled basal")
        case .error(let status):
            switch status {
            case .noDelivery:
                Text("No Delivery")
            case .suspended:
                Text("Insulin Suspended")
            }
        }
    }
    
    var statusSubtitle: Text? {
        switch state {
        case .automationOn(.moreThanScheduled):
            Text("Includes basal and automated boluses")
        default:
            nil
        }
    }
    
    var currentBasalRateSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Current Basal Rate")
            
            Group {
                Text(rateFormatter.string(from: currentBasalRate.quantity, includeUnit: false) ?? "Unknown").fontWeight(.semibold) + Text(" ") + Text(currentBasalRate.quantity.unit.localizedUnitString(in: .short) ?? "U/hr")
            }
            .font(.title2)
            
            Text("since \(currentBasalRate.date.formatted(date: .omitted, time: .shortened))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    
    var lastAutoBolusSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Last Auto Bolus")
            
            Group {
                if let lastAutoBolus, state != .automationOff {
                    Text(bolusFormatter.string(from: lastAutoBolus.quantity, includeUnit: false) ?? "Unknown").fontWeight(.semibold) + Text(" ") + Text(lastAutoBolus.quantity.unit.localizedUnitString(in: .short) ?? "U")
                } else {
                    Text(" ")
                }
            }
            .font(.title2)
            
            Group {
                if state == .automationOff {
                    Text("Automation is off")
                        .italic()
                } else if let lastAutoBolus {
                    Text("at \(lastAutoBolus.date.formatted(date: .omitted, time: .shortened))")
                } else {
                    Text("")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Delivery")
                
                HStack(spacing: 4) {
                    icon
                    
                    statusTitle
                        .font(.title3.weight(.heavy))
                }
            
                if let statusSubtitle {
                    statusSubtitle
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                }
                
                Text("at \(time.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            ViewThatFits {
                HStack(spacing: 0) {
                    currentBasalRateSection
                    
                    Spacer()
                    
                    lastAutoBolusSection
                        .foregroundStyle(state == .automationOn(basalStatus: .lessThanScheduled) ? .secondary : .primary)
                }
            }
        }
    }
}

#Preview {
    let time = Date()
    let currentBasalRate = DatedQuantity(date: Date(), quantity: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.5))
    let lastAutoBolus = DatedQuantity(date: Date(), quantity: LoopQuantity(unit: .internationalUnit, doubleValue: 0.05))
    
    Group {
        InsulinDeliveryOverview(
            state: .automationOn(basalStatus: .scheduled),
            time: time,
            currentBasalRate: currentBasalRate,
            lastAutoBolus: lastAutoBolus
        )
        
        InsulinDeliveryOverview(
            state: .automationOn(basalStatus: .moreThanScheduled),
            time: time,
            currentBasalRate: currentBasalRate,
            lastAutoBolus: lastAutoBolus
        )
        
        InsulinDeliveryOverview(
            state: .automationOn(basalStatus: .lessThanScheduled),
            time: time,
            currentBasalRate: currentBasalRate,
            lastAutoBolus: lastAutoBolus
        )
        
        InsulinDeliveryOverview(
            state: .automationOff,
            time: time,
            currentBasalRate: currentBasalRate,
            lastAutoBolus: lastAutoBolus
        )
        
        InsulinDeliveryOverview(
            state: .error(status: .noDelivery),
            time: time,
            currentBasalRate: currentBasalRate,
            lastAutoBolus: lastAutoBolus
        )
        
        InsulinDeliveryOverview(
            state: .error(status: .suspended),
            time: time,
            currentBasalRate: currentBasalRate,
            lastAutoBolus: lastAutoBolus
        )
    }
    .environment(\.guidanceColors, .default)
}
