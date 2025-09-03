//
//  InsulinDeliveryEventDetailsView.swift
//  Loop
//
//  Created by Cameron Ingham on 7/7/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import SwiftUI

struct InsulinDeliveryEventDetailsView: View {
    
    let basalUnitsFormatter = QuantityFormatter(for: .internationalUnitsPerHour)
    let bolusUnitsFormatter = QuantityFormatter(for: .internationalUnit)
    let durationFormatter = DateComponentsFormatter()
    
    let pumpEventType: InsulinDeliveryLogEvent.EventType.PumpEventType
    let doseEntry: DoseEntry
    let onTapGesture: (DoseEntry) -> Void
    
    var doseTypeValue: String {
        switch pumpEventType {
        case .basal(let basalEventType, _):
            switch basalEventType {
            case .automatedPresetBasal:
                return NSLocalizedString("Temp Basal", comment: "")
            case .automationOff:
                return NSLocalizedString("Scheduled Basal", comment: "")
            case .automationOn(basalStatus: let basalStatus):
                switch basalStatus {
                case .lessThanScheduled:
                    return NSLocalizedString("Temp Basal", comment: "")
                case .moreThanScheduled:
                    return NSLocalizedString("Temp Basal", comment: "")
                case .scheduled:
                    return NSLocalizedString("Scheduled Basal", comment: "")
                }
            case .manualTempBasal:
                return NSLocalizedString("Temp Basal", comment: "")
            }
        case .bolus:
            return NSLocalizedString("Bolus", comment: "")
        case .insulin(let insulinEventType):
            switch insulinEventType {
            case .resumed:
                return NSLocalizedString("Insulin Resumed", comment: "")
            case .suspended:
                return NSLocalizedString("Insulin Suspended", comment: "")
            }
        }
    }
    
    var startTimeValue: String? {
        doseEntry.startDate.formatted(date: .omitted, time: .standard)
    }

    var endTimeValue: String? {
        doseEntry.endDate.formatted(date: .omitted, time: .standard)
    }

    var durationValue: String? {
        durationFormatter.unitsStyle = .abbreviated
        
        return durationFormatter.string(from: doseEntry.duration)
    }
    
    var deliveredUnitsValue: String? {
        switch pumpEventType {
        case .basal(_, let rate):
            return basalUnitsFormatter.string(from: rate)
        case .bolus(_, _, let deliveryAmount):
            return bolusUnitsFormatter.string(from: deliveryAmount)
        case .insulin:
            return basalUnitsFormatter.string(from: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: 0))
        }
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    Text("Dose Type")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(doseTypeValue)
                }
                
                if let startTimeValue {
                    VStack(alignment: .leading) {
                        Text("Start Time")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(startTimeValue)
                    }
                }

                if let endTimeValue {
                    VStack(alignment: .leading) {
                        Text("End Time")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(endTimeValue)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Mutable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(doseEntry.isMutable ? "Yes" : "No")
                }

                switch pumpEventType {
                case .basal, .bolus:
                    if let durationValue {
                        VStack(alignment: .leading) {
                            Text("Duration")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text(durationValue)
                        }
                    }
                    
                    if let deliveredUnitsValue {
                        VStack(alignment: .leading) {
                            Text("Insulin Delivery")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text(deliveredUnitsValue)
                        }
                    }
                case .insulin:
                    EmptyView()
                }
            } header: {
                Text("Delivery Details")
            }
            .navigationTitle(Text("Insulin Event"))
            .contentShape(Rectangle())
            .onTapGesture {
                onTapGesture(doseEntry)
            }
        }
    }
}
