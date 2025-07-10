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
    
    let totalDeliveredFormatter: QuantityFormatter = {
        let formatter = QuantityFormatter(for: .internationalUnit)
        
        formatter.numberFormatter.maximumFractionDigits = 0
        
        return formatter
    }()
    
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
        
        for dose in doses {
            let automationEnabledDuringDose = loopDataManager.automationHistory.toTimeline(from: dose.startDate, to: dose.endDate).first(where: { $0.startDate >= dose.startDate && $0.endDate <= dose.startDate })?.value ?? false
            let presetEnabledDuringDose = loopDataManager.temporaryPresetsManager.presetHistory.activeOverride(at: dose.startDate) != nil
            
            switch dose.type {
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
                                        dose
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
                                        dose
                                    ),
                                    date: dose.startDate
                                )
                            )
                        } else {
                            fatalError()
                        }
                    } else {
                        fatalError()
                        // Correct, this should never happen
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
                                dose
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
                                dose
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
                                        dose
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
                                        dose
                                    ),
                                    date: decision.date
                                )
                            )
                        }
                    } else {
                        fatalError()
                        // Can hit with pump with external events not handles by Loop
                    }
                }
            case .resume:
                events.insert(InsulinDeliveryLogEvent(id: dose.syncIdentifier ?? UUID().uuidString, type: .pumpEvent(.insulin(.resumed), dose), date: dose.startDate))
            case .suspend:
                events.insert(InsulinDeliveryLogEvent(id: dose.syncIdentifier ?? UUID().uuidString, type: .pumpEvent(.insulin(.suspended), dose), date: dose.startDate))
            case .tempBasal:
                if let basalSchedule = loopDataManager.temporaryPresetsManager.basalRateScheduleApplyingOverrideHistory?.value(at: dose.startDate) {
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
                                    dose
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
                                    dose
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
                                    dose
                                ),
                                date: dose.startDate
                            )
                        )
                    } else if presetEnabledDuringDose && dose.unitsPerHour == basalSchedule {
                        events.insert(
                            InsulinDeliveryLogEvent(
                                id: dose.syncIdentifier ?? UUID().uuidString,
                                type: .pumpEvent(
                                    .basal(
                                        .automatedPresetBasal,
                                        rate: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: dose.unitsPerHour)
                                    ),
                                    dose
                                ),
                                date: dose.startDate
                            )
                        )
                    } else {
                        fatalError()
                    }
                } else {
                    events.insert(
                        InsulinDeliveryLogEvent(
                            id: dose.syncIdentifier ?? UUID().uuidString,
                            type: .pumpEvent(
                                .basal(
                                    .manualTempBasal(
                                        endDate: dose.endDate
                                    ),
                                    rate: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: dose.value)
                                ),
                                dose
                            ),
                            date: dose.startDate
                        )
                    )
                }
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
    
    let onTapGesture: (DoseEntry) -> Void
    
    init(viewModel: InsulinDeliveryLogViewModel, onTapGesture: @escaping (DoseEntry) -> Void) {
        self.viewModel = viewModel
        self.onTapGesture = onTapGesture
    }
    
    @ViewBuilder
    private func totalInsulinDeliveredLabel(from total: LoopQuantity) -> some View {
        LabeledContent {
            Text(viewModel.totalDeliveredFormatter.string(from: total) ?? "Unknown")
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
            
            Menu("Filter") {
                Button { } label: {
                    Text("Filter")
                    Text("Event")
                }
                
                Picker("Filter", selection: .constant(0)) {
                    Text("A")
                        .tag(0)
                    Text("B")
                        .tag(1)
                    Text("C")
                        .tag(2)
                }
            }
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
                ZStack {
                    InsulinDeliveryLogEventRow(event: event)
                    
                    if case let .pumpEvent(pumpEventType, doseEntry) = event.type, let doseEntry {
                        NavigationLink {
                            InsulinDeliveryEventDetailsView(pumpEventType: pumpEventType, doseEntry: doseEntry, onTapGesture: onTapGesture)
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                }
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
