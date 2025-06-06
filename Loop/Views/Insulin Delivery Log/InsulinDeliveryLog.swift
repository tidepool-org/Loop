//
//  InsulinDeliveryLog.swift
//  Loop
//
//  Created by Cameron Ingham on 3/25/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import LoopKitUI
import SwiftUI

@MainActor
@Observable
class InsulinDeliveryLogViewModel {
    
    struct DisplayData: Hashable {
        let insulinDeliveryState: InsulinDeliveryOverview.State, insulinDeliveryStateUpdatedDate: Date, currentBasalRate: DatedQuantity, lastAutoBolus: DatedQuantity?, totalInsulinDelivered: LoopQuantity, events: Set<InsulinDeliveryLogEvent>
    }
    
    enum State: Hashable {
        enum FetchError {
            case noBasalRateSchedule
        }
        
        case loading
        case fetched(DisplayData)
        case refreshing(DisplayData)
        case error(FetchError)
    }
    
    let bolusFormatter = QuantityFormatter(for: .internationalUnit)
    
    private let loopDataManager: LoopDataManager
    private let pumpManager: PumpManager?
    
    private(set) var state: State
    
    var logEventDisplays: [LogEventDisplay] {
        var displayEvents: [LogEventDisplay] = []
        
        switch state {
        case .fetched(let data), .refreshing(let data):
            Array(Array(data.events.filter({ $0.date >= Date().addingTimeInterval(.days(-1)) })).sortedByDate().segmentItemsByHour().sorted(by: { $0.key.lowerBound > $1.key.lowerBound })).forEach { range, events in
                displayEvents.append(.title(id: UUID(), "\(range.lowerBound.formatted(date: .omitted, time: .shortened)) - \(range.upperBound.formatted(date: .omitted, time: .shortened))"))
                events.sortedByDate().forEach { event in
                    displayEvents.append(.event(event))
                }
            }
        case .loading, .error:
            break
        }
        
        return displayEvents
    }
    
    private var doseStoreObserver: Any? {
        willSet {
            if let observer = doseStoreObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    private var doseStore: DoseStore! {
        didSet {
            if let doseStore = doseStore {
                doseStoreObserver = NotificationCenter.default.addObserver(forName: nil, object: doseStore, queue: OperationQueue.main, using: { [weak self] note in

                    switch note.name {
                    case DoseStore.valuesDidChange:
                        Task { @MainActor in
                            await self?.fetchData()
                        }
                    default:
                        break
                    }
                })
            } else {
                doseStoreObserver = nil
            }
        }
    }
    
    init(
        loopDataManager: LoopDataManager,
        pumpManager: PumpManager?,
        initialState: State = .loading,
        autoRefresh: Bool = true
    ) {
        self.loopDataManager = loopDataManager
        self.pumpManager = pumpManager
        self.state = initialState
        
        self.doseStore = (loopDataManager.doseStore as? DoseStore)
        
        Task {
            await fetchData()
        }
    }

    func fetchData() async {
        if case let .fetched(data) = state {
            state = .refreshing(data)
        }
        
        var insulinDeliveryState: InsulinDeliveryOverview.State
        var totalInsulinDelivered: LoopQuantity
        var currentBasalRate: DatedQuantity
        var lastAutoBolus: DatedQuantity?
        var events: Set<InsulinDeliveryLogEvent> = []
        
        let startDate = Date().addingTimeInterval(.days(-1))
        
        // Current Basal Rate
        guard let basalRateSchedule = loopDataManager.temporaryPresetsManager.basalRateScheduleApplyingOverrideHistory ?? loopDataManager.settings.basalRateSchedule else {
            state = .error(.noBasalRateSchedule)
            return
        }
    
        let currentValue = basalRateSchedule.scheduleSegment(at: Date())
        currentBasalRate = DatedQuantity(date: currentValue.startDate, quantity: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: currentValue.value))

        insulinDeliveryState = .automationOn(basalStatus: .scheduled) // FIXME: Update

        // Basal and Bolus
        let doses: [DoseEntry] = (try? await loopDataManager.doseStore.getNormalizedDoseEntries(start: startDate, end: Date())) ?? []

        // Last Auto Bolus
        if let lastAutoBolusDose = doses.filter({ $0.automatic == true }).last {
            lastAutoBolus = DatedQuantity(date: lastAutoBolusDose.startDate, quantity: LoopQuantity(unit: .internationalUnit, doubleValue: lastAutoBolusDose.deliveredUnits ?? lastAutoBolusDose.value))
        }
        
        // Total Insulin Delivered
        totalInsulinDelivered = await LoopQuantity(unit: .internationalUnit, doubleValue: loopDataManager.totalDeliveredToday()?.value ?? 0)
        
        let pumpEvents = (try? await getPumpEvents(since: startDate)) ?? []
        for pumpEvent in pumpEvents {
            guard let dose = pumpEvent.dose else {
                return
            }
            
            let automationEnabledDuringDose = loopDataManager.automationHistory.toTimeline(from: dose.startDate, to: dose.endDate).first(where: { $0.startDate >= dose.startDate && $0.endDate <= dose.startDate })?.value ?? false
            let presetEnabledDuringDose = loopDataManager.temporaryPresetsManager.presetHistory.activeOverride(at: dose.startDate) != nil
            
            switch pumpEvent.type {
            case .basal:
                if automationEnabledDuringDose {
                    if let basalSchedule = loopDataManager.settings.basalRateSchedule?.value(at: dose.startDate) {
                        if dose.unitsPerHour == basalSchedule {
                            events.insert(
                                InsulinDeliveryLogEvent(
                                    id: dose.syncIdentifier ?? UUID().uuidString,
                                    type: .pumpEvent(
                                        .basal(
                                            .automationOn(basalStatus: .scheduled),
                                            rate: LoopQuantity(
                                                unit: .internationalUnitsPerHour,
                                                doubleValue: dose.unitsPerHour
                                            )
                                        ),
                                        pumpEvent
                                    ),
                                    date: dose.startDate
                                )
                            )
                        } else if presetEnabledDuringDose {
                            events.insert(
                                InsulinDeliveryLogEvent(
                                    id: dose.syncIdentifier ?? UUID().uuidString,
                                    type: .pumpEvent(
                                        .basal(
                                            .automatedPresetBasal,
                                            rate: LoopQuantity(
                                                unit: .internationalUnitsPerHour,
                                                doubleValue: dose.unitsPerHour
                                            )
                                        ),
                                        pumpEvent
                                    ),
                                    date: dose.startDate
                                )
                            )
                        } else {
                            fatalError()
                        }
                    } else {
                        fatalError()
                    }
                } else {
                    events.insert(
                        InsulinDeliveryLogEvent(
                            id: dose.syncIdentifier ?? UUID().uuidString,
                            type: .pumpEvent(
                                .basal(
                                    .automationOff,
                                    rate: LoopQuantity(
                                        unit: .internationalUnitsPerHour,
                                        doubleValue: dose.unitsPerHour
                                    )
                                ),
                                pumpEvent
                            ),
                            date: dose.startDate
                        )
                    )
                }
            case .bolus:
                if dose.automatic == true {
                    events.insert(
                        InsulinDeliveryLogEvent(
                            id: dose.syncIdentifier ?? UUID().uuidString,
                            type: .pumpEvent(
                                .bolus(
                                    .automated,
                                    programmedAmount: LoopQuantity(
                                        unit: .internationalUnit,
                                        doubleValue: dose.programmedUnits
                                    ),
                                    deliveryAmount: LoopQuantity(
                                        unit: .internationalUnit,
                                        doubleValue: dose.deliveredUnits ?? dose.programmedUnits
                                    )
                                ),
                                pumpEvent
                            ),
                            date: dose.startDate
                        )
                    )
                } else {
                    if let decisionId = dose.decisionId, let decision = try? await loopDataManager.dosingDecisionStore.findDosingDecisionsById(decisionId), let recommendedUnits = decision.manualBolusRecommendation?.recommendation.amount {
                        if let carbEntry = decision.carbEntry {
                            events.insert(
                                InsulinDeliveryLogEvent(
                                    id: decision.syncIdentifier.uuidString,
                                    type: .pumpEvent(
                                        .bolus(
                                            .meal(
                                                recommendedAmount: LoopQuantity(
                                                    unit: .internationalUnit,
                                                    doubleValue: recommendedUnits
                                                ),
                                                carbAmount: LoopQuantity(
                                                    unit: .gram,
                                                    doubleValue: carbEntry.amount
                                                ),
                                                emoji: carbEntry.foodType ?? ""
                                            ),
                                            programmedAmount: LoopQuantity(
                                                unit: .internationalUnit,
                                                doubleValue: decision.manualBolusRequested ?? 0
                                            ),
                                            deliveryAmount: LoopQuantity(
                                                unit: .internationalUnit,
                                                doubleValue: dose.deliveredUnits ?? dose.programmedUnits
                                            )
                                        ),
                                        pumpEvent
                                    ),
                                    date: decision.date
                                )
                            )
                        } else {
                            events.insert(
                                InsulinDeliveryLogEvent(
                                    id: decision.syncIdentifier.uuidString,
                                    type: .pumpEvent(
                                        .bolus(
                                            .correction(
                                                recommendedAmount: LoopQuantity(
                                                    unit: .internationalUnit,
                                                    doubleValue: recommendedUnits
                                                )
                                            ),
                                            programmedAmount: LoopQuantity(
                                                unit: .internationalUnit,
                                                doubleValue: decision.manualBolusRequested ?? 0
                                            ),
                                            deliveryAmount: LoopQuantity(
                                                unit: .internationalUnit,
                                                doubleValue: dose.deliveredUnits ?? dose.programmedUnits
                                            )
                                        ),
                                        pumpEvent
                                    ),
                                    date: decision.date
                                )
                            )
                        }
                    } else {
                        fatalError()
                    }
                }
            case .resume:
                events.insert(InsulinDeliveryLogEvent(id: String(pumpEvent.hashValue), type: .pumpEvent(.insulin(.resumed), pumpEvent), date: pumpEvent.date))
            case .suspend:
                events.insert(InsulinDeliveryLogEvent(id: String(pumpEvent.hashValue), type: .pumpEvent(.insulin(.suspended), pumpEvent), date: pumpEvent.date))
            case .tempBasal:
                if let deliveredUnits = dose.deliveredUnits, let basalSchedule = loopDataManager.temporaryPresetsManager.basalRateScheduleApplyingOverrideHistory?.value(at: startDate) {
                    if dose.automatic == false {
                        events.insert(
                            InsulinDeliveryLogEvent(
                                id: dose.syncIdentifier ?? UUID().uuidString,
                                type: .pumpEvent(
                                    .basal(
                                        .manualTempBasal(endDate: dose.endDate),
                                        rate: LoopQuantity(
                                            unit: .internationalUnitsPerHour,
                                            doubleValue: dose.unitsPerHour
                                        )
                                    ),
                                    pumpEvent
                                ),
                                date: dose.startDate
                            )
                        )
                    } else if dose.unitsPerHour < basalSchedule {
                        events.insert(
                            InsulinDeliveryLogEvent(
                                id: dose.syncIdentifier ?? UUID().uuidString,
                                type: .pumpEvent(
                                    .basal(
                                        .automationOn(basalStatus: .lessThanScheduled),
                                        rate: LoopQuantity(
                                            unit: .internationalUnitsPerHour,
                                            doubleValue: dose.unitsPerHour
                                        )
                                    ),
                                    pumpEvent
                                ),
                                date: dose.startDate
                            )
                        )
                    } else if dose.unitsPerHour > basalSchedule {
                        events.insert(
                            InsulinDeliveryLogEvent(
                                id: dose.syncIdentifier ?? UUID().uuidString,
                                type: .pumpEvent(
                                    .basal(
                                        .automationOn(basalStatus: .moreThanScheduled),
                                        rate: LoopQuantity(
                                            unit: .internationalUnitsPerHour,
                                            doubleValue: dose.unitsPerHour
                                        ),
                                    ),
                                    pumpEvent
                                ),
                                date: dose.startDate
                            )
                        )
                    } else {
                        fatalError()
                    }
                } else {
                    dump(dose)
//                    fatalError()
                }
            default:
                break
            }
        }
        
        // Automation
        loopDataManager.automationHistory.forEach { event in
            if event.enabled {
                events.insert(InsulinDeliveryLogEvent(id: String(event.hashValue), type: .automation(.on), date: event.startDate))
            } else {
                events.insert(InsulinDeliveryLogEvent(id: String(event.hashValue), type: .automation(.off(endDate: nil)), date: event.startDate))
            }
        }
        
        // Preset
        loopDataManager.temporaryPresetsManager.presetHistory.recentEvents.filter({ $0.override.actualEndDate >= startDate }).forEach { event in
            if let preset = loopDataManager.temporaryPresetsManager.selectablePresets.first(where: { $0.id == event.override.presetId }) {
                events.insert(InsulinDeliveryLogEvent(id: String(event.hashValue), type: .preset(.enabled, icon: preset.icon, name: preset.name), date: event.override.startDate))
                
                if event.override.hasFinished() {
                    events.insert(InsulinDeliveryLogEvent(id: String(event.hashValue), type: .preset(.disabled, icon: preset.icon, name: preset.name), date: event.override.actualEndDate))
                }
            }
        }
        
        state = .fetched(.init(insulinDeliveryState: insulinDeliveryState, insulinDeliveryStateUpdatedDate: Date(), currentBasalRate: currentBasalRate, lastAutoBolus: lastAutoBolus, totalInsulinDelivered: totalInsulinDelivered, events: events))
    }
    
    private func getPumpEvents(since sinceDate: Date) async throws -> [PersistedPumpEvent] {
        let events = try? await (loopDataManager.doseStore as? DoseStore)?.getPumpEventValues(since: sinceDate)
        return events?.filter { event in
            return event.dose != nil
        } ?? []
    }
}

enum LogEventDisplay: Hashable, Identifiable {
    case title(id: UUID, String)
    case event(InsulinDeliveryLogEvent)
    
    var id: Int {
        hashValue
    }
}

struct InsulinDeliveryLog: View {
    
    @State private var viewModel: InsulinDeliveryLogViewModel
    
    let onTapGesture: (InsulinDeliveryLogEvent) -> Void
    
    init(viewModel: InsulinDeliveryLogViewModel, onTapGesture: @escaping (InsulinDeliveryLogEvent) -> Void) {
        self.viewModel = viewModel
        self.onTapGesture = onTapGesture
    }
    
    @ViewBuilder
    private func totalInsulinDeliveredLabel(from total: LoopQuantity) -> some View {
        LabeledContent {
            Text(viewModel.bolusFormatter.string(from: total) ?? "Unknown")
                .foregroundStyle(.secondary)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Total Insulin Delivery")
                
                Text("since \(Calendar.current.startOfDay(for: Date()).formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var deliveryLogHeader: some View {
        HStack(spacing: 0) {
            Text("Insulin Delivery Log")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(UIColor.label))
            
            Spacer()
            
            Button("Filter") {
                
            }
            .font(.body.weight(.regular))
        }
        .textCase(nil)
    }
    
    private var deliveryLog: some View {
        ForEach(viewModel.logEventDisplays) { displayEvent in
            switch displayEvent {
            case .title(_, let title):
                Text(title)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemGray5))
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            case .event(let event):
                InsulinDeliveryLogEventRow(event: event)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapGesture(event) }
            }
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in
            return 0
        }
    }
    
    var body: some View {
        List {
            switch viewModel.state {
            case .loading:
                ActivityIndicator(isAnimating: .constant(true), style: .default)
                    .frame(maxWidth: .infinity)
            case .fetched(let data), .refreshing(let data):
                Section {
                    InsulinDeliveryOverview(
                        state: data.insulinDeliveryState,
                        time: data.insulinDeliveryStateUpdatedDate,
                        currentBasalRate: data.currentBasalRate,
                        lastAutoBolus: data.lastAutoBolus
                    )
                }
                
                Section {
                    totalInsulinDeliveredLabel(from: data.totalInsulinDelivered)
                }
            case .error(let fetchError):
                switch fetchError {
                case .noBasalRateSchedule: // FIXME: Needed?
                    Text("No Basal Rate Schedule")
                }
            }
            
            Section {
                deliveryLog
            } header: {
                deliveryLogHeader
            }
        }
        .refreshable {
            await viewModel.fetchData()
        }
    }
}
