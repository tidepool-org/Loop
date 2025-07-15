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

fileprivate enum FilterOptions: Hashable, CaseIterable {
    case userInitiated
    case all
    
    var localizedMenuTitle: String {
        switch self {
        case .userInitiated:
            NSLocalizedString("Self-Initiated Events", comment: "")
        case .all:
            NSLocalizedString("All Events", comment: "")
        }
    }
}

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
        
        formatter.numberFormatter.maximumFractionDigits = 1
        
        return formatter
    }()
    
    private let loopDataManager: LoopDataManager
    private let pumpManager: PumpManager?
    
    private(set) var state: State
    
    fileprivate var selectedFilterOption: FilterOptions = .all
    
    var logEventDisplays: [LogEventDisplay] {
        var displayEvents: [LogEventDisplay] = []
        
        switch state {
        case .fetched(let data), .refreshing(let data):
            Array(Array(data.events.filter({
                switch selectedFilterOption {
                case .userInitiated:
                    switch $0.type {
                    case .automation,
                            .preset,
                            .pumpEvent(.basal(.manualTempBasal, rate: _), _),
                            .pumpEvent(.insulin, _),
                            .pumpEvent(.bolus(.correction, _, _), _),
                            .pumpEvent(.bolus(.meal, _, _), _):
                        return true
                    default:
                        return false
                    }
                case .all:
                    return true
                }
            }).filter({
                $0.date >= Date().addingTimeInterval(.days(-1))
            })).sortedByDate().segmentItemsByHour().sorted(by: { $0.key.lowerBound > $1.key.lowerBound })).forEach { range, events in
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
    
    var eventCount: Int {
        logEventDisplays.filter { display in
            switch display {
            case .event:
                return true
            case .title:
                return false
            }
        }.count
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
        initialState: State = .loading
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
        
        let fetchedDate = Date()
        let startDate = fetchedDate.addingTimeInterval(.days(-1))

        // Status State
        var insulinSuspended = false
        if case .suspended = pumpManager?.status.basalDeliveryState {
            insulinSuspended = true
        }
        
        let automationEnabled = loopDataManager.automaticDosingStatus.automaticDosingEnabled
        let automatedTreatmentState = pumpManager?.pumpManagerDelegate?.automatedTreatmentState ?? .neutralNoOverride

        if insulinSuspended {
            insulinDeliveryState = .error(status: .suspended)
        } else if automationEnabled {
            let basalStatus: InsulinDeliveryOverview.State.AutomatedBasalStatus
            switch automatedTreatmentState {
            case .neutralNoOverride, .neutralOverride:
                basalStatus = .scheduled
            case .increasedInsulin:
                basalStatus = .moreThanScheduled
            case .decreasedInsulin, .minimumDelivery:
                basalStatus = .lessThanScheduled
            }
            
            insulinDeliveryState = .automationOn(basalStatus: basalStatus, preset: loopDataManager.temporaryPresetsManager.activePreset)
        } else {
            insulinDeliveryState = .automationOff
        }
        
        // Current Basal Rate
        guard let basalRateSchedule = loopDataManager.temporaryPresetsManager.basalRateScheduleApplyingOverrideHistory ?? loopDataManager.settings.basalRateSchedule else {
            state = .error(.noBasalRateSchedule)
            return
        }
    
        let currentValue = basalRateSchedule.scheduleSegment(at: startDate)
        currentBasalRate = DatedQuantity(date: currentValue.startDate, quantity: LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: currentValue.value))

        // Basal and Bolus
        let doses: [DoseEntry] = (try? await loopDataManager.doseStore.getNormalizedDoseEntries(start: startDate, end: nil)) ?? []

        // Last Auto Bolus
        if let lastAutoBolusDose = doses.filter({ $0.automatic == true }).last {
            lastAutoBolus = DatedQuantity(date: lastAutoBolusDose.startDate, quantity: LoopQuantity(unit: .internationalUnit, doubleValue: lastAutoBolusDose.deliveredUnits ?? lastAutoBolusDose.value))
        }
        
        // Total Insulin Delivered
        totalInsulinDelivered = await LoopQuantity(unit: .internationalUnit, doubleValue: loopDataManager.totalDeliveredToday()?.value ?? 0)
        
        // Insulin Events
        for dose in doses {
            let automationEnabledDuringDose = loopDataManager.automationHistory.automationEnabled(at: dose.startDate) ?? loopDataManager.automaticDosingStatus.automaticDosingEnabled
            
            var decision: StoredDosingDecision?
            if let decisionId = dose.decisionId {
                decision = try? await loopDataManager.dosingDecisionStore.findDosingDecisionsById(decisionId)
            }
            
            switch dose.type {
            case .basal, .tempBasal:
                if dose.type == .tempBasal && dose.automatic == false {
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
                } else if automationEnabledDuringDose {
                    if let decision {
                        if decision.scheduleOverride != nil {
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
                            if let direction = decision.automaticDoseRecommendation?.direction {
                                switch direction {
                                case .decrease:
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
                                case .neutral:
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
                                case .increase:
                                    events.insert(
                                        InsulinDeliveryLogEvent(
                                            id: dose.syncIdentifier ?? UUID().uuidString,
                                            type: .pumpEvent(
                                                .basal(
                                                    .automationOn(basalStatus: .moreThanScheduled),
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
                            } else {
                                fatalError("No `decision.automaticDoseRecommendation`")
                            }
                        }
                    } else if let scheduledBasalRate = dose.scheduledBasalRate, scheduledBasalRate.doubleValue(for: .internationalUnitsPerHour) == dose.value {
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
                    } else {
                        fatalError("No `decision` or `scheduledBasalRate`")
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
                    if let recommendedUnits = decision?.manualBolusRecommendation?.recommendation.amount {
                        if let carbEntry = decision?.carbEntry {
                            events.insert(
                                InsulinDeliveryLogEvent(
                                    id: decision?.syncIdentifier.uuidString ?? UUID().uuidString,
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
                                                doubleValue: decision?.manualBolusRequested ?? 0
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
                            events.insert(
                                InsulinDeliveryLogEvent(
                                    id: decision?.syncIdentifier.uuidString ?? UUID().uuidString,
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
                                                doubleValue: decision?.manualBolusRequested ?? 0
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
                        }
                    } else {
                        events.insert(
                            InsulinDeliveryLogEvent(
                                id: dose.syncIdentifier ?? UUID().uuidString,
                                type: .pumpEvent(
                                    .bolus(
                                        .correction(recommendedAmount: nil),
                                        programmedAmount: nil,
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
                    }
                }
            case .resume:
                break
            case .suspend:
                events.insert(InsulinDeliveryLogEvent(id: dose.syncIdentifier ?? UUID().uuidString, type: .pumpEvent(.insulin(.suspended), dose), date: dose.startDate))
                
                if !dose.isMutable || dose.endDate <= fetchedDate {
                    events.insert(InsulinDeliveryLogEvent(id: dose.syncIdentifier ?? UUID().uuidString, type: .pumpEvent(.insulin(.resumed), dose), date: dose.endDate))
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
        
        state = .fetched(.init(insulinDeliveryState: insulinDeliveryState, insulinDeliveryStateUpdatedDate: fetchedDate, currentBasalRate: currentBasalRate, lastAutoBolus: lastAutoBolus, totalInsulinDelivered: totalInsulinDelivered, events: events))
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
    @State var showingFilterMenu = false
    
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
    
    private var filterMenu: some View {
        Menu("Filter") {
            Button { } label: {
                Text("Filter")
                Text("Event")
            }
            
            Picker("Filter", selection: $viewModel.selectedFilterOption) {
                ForEach(FilterOptions.allCases, id: \.self) { option in
                    Text(option.localizedMenuTitle)
                        .tag(option)
                }
            }
        }
    }
    
    private var deliveryLogHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("Insulin Delivery Log")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color(UIColor.label))
                
                Spacer()
                
                filterMenu
            }
            
            if viewModel.selectedFilterOption != .all {
                HStack(spacing: 8) {
                    Text("Filtered by:")
                        .foregroundStyle(Color(UIColor.systemGray))
                    
                    HStack(spacing: 4) {
                        Text(viewModel.selectedFilterOption.localizedMenuTitle)
                        
                        Button {
                            viewModel.selectedFilterOption = .all
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .padding(4)
                    .padding(.leading, 4)
                    .background(Color.accentColor.clipShape(Capsule()))
                    .foregroundStyle(Color(UIColor.systemBackground))
                }
                .font(.subheadline)
            }
        }
        .textCase(nil)
        .padding(.bottom, 4)
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
