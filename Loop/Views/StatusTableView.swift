//
//  StatusTableView.swift
//  Loop
//
//  Created by Cameron Ingham on 12/10/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import LoopKitUI
import SwiftUI
import UIKit

private struct WrappedStatusTableViewController: UIViewControllerRepresentable {
    
    private let alertPermissionsChecker: AlertPermissionsChecker
    private let alertMuter: AlertMuter
    private let deviceDataManager: DeviceDataManager
    private let onboardingManager: OnboardingManager
    private let supportManager: SupportManager
    private let testingScenariosManager: TestingScenariosManager?
    private let settingsManager: SettingsManager
    private let temporaryPresetsManager: TemporaryPresetsManager
    private let loopDataManager: LoopDataManager
    private let diagnosticReportGenerator: DiagnosticReportGenerator
    private let simulatedData: SimulatedData
    private let analyticsServicesManager: AnalyticsServicesManager
    private let servicesManager: ServicesManager
    private let carbStore: CarbStore
    private let doseStore: DoseStore
    private let criticalEventLogExportManager: CriticalEventLogExportManager
    private let bluetoothStateManager: BluetoothStateManager
    private let statusTableViewModel: StatusTableViewModel
    
    let viewController: StatusTableViewController
    
    init(alertPermissionsChecker: AlertPermissionsChecker, alertMuter: AlertMuter, deviceDataManager: DeviceDataManager, onboardingManager: OnboardingManager, supportManager: SupportManager, testingScenariosManager: TestingScenariosManager?, settingsManager: SettingsManager, temporaryPresetsManager: TemporaryPresetsManager, loopDataManager: LoopDataManager, diagnosticReportGenerator: DiagnosticReportGenerator, simulatedData: SimulatedData, analyticsServicesManager: AnalyticsServicesManager, servicesManager: ServicesManager, carbStore: CarbStore, doseStore: DoseStore, criticalEventLogExportManager: CriticalEventLogExportManager, bluetoothStateManager: BluetoothStateManager, statusTableViewModel: StatusTableViewModel) {
        self.alertPermissionsChecker = alertPermissionsChecker
        self.alertMuter = alertMuter
        self.deviceDataManager = deviceDataManager
        self.onboardingManager = onboardingManager
        self.supportManager = supportManager
        self.testingScenariosManager = testingScenariosManager
        self.settingsManager = settingsManager
        self.temporaryPresetsManager = temporaryPresetsManager
        self.loopDataManager = loopDataManager
        self.diagnosticReportGenerator = diagnosticReportGenerator
        self.simulatedData = simulatedData
        self.analyticsServicesManager = analyticsServicesManager
        self.servicesManager = servicesManager
        self.carbStore = carbStore
        self.doseStore = doseStore
        self.criticalEventLogExportManager = criticalEventLogExportManager
        self.bluetoothStateManager = bluetoothStateManager
        self.statusTableViewModel = statusTableViewModel
        
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: StatusTableViewController.self))
        let statusTableViewController = storyboard.instantiateViewController(withIdentifier: "MainStatusViewController") as! StatusTableViewController
        statusTableViewController.alertPermissionsChecker = alertPermissionsChecker
        statusTableViewController.alertMuter = alertMuter
        statusTableViewController.deviceManager = deviceDataManager
        statusTableViewController.onboardingManager = onboardingManager
        statusTableViewController.supportManager = supportManager
        statusTableViewController.testingScenariosManager = testingScenariosManager
        statusTableViewController.settingsManager = settingsManager
        statusTableViewController.temporaryPresetsManager = temporaryPresetsManager
        statusTableViewController.loopManager = loopDataManager
        statusTableViewController.diagnosticReportGenerator = diagnosticReportGenerator
        statusTableViewController.simulatedData = simulatedData
        statusTableViewController.analyticsServicesManager = analyticsServicesManager
        statusTableViewController.servicesManager = servicesManager
        statusTableViewController.carbStore = carbStore
        statusTableViewController.doseStore = doseStore
        statusTableViewController.criticalEventLogExportManager = criticalEventLogExportManager
        statusTableViewController.statusTableViewModel = statusTableViewModel
        bluetoothStateManager.addBluetoothObserver(statusTableViewController)
        
        self.viewController = statusTableViewController
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}

struct StatusTableView: View {
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isLandscape: Bool {
        UIScreen.main.bounds.size.width > UIScreen.main.bounds.size.height
    }
    
    private let wrapped: WrappedStatusTableViewController
    
    var viewController: StatusTableViewController {
        wrapped.viewController
    }
    
    @ViewBuilder
    var wrappedView: some View { wrapped }
    
    @Bindable var viewModel: StatusTableViewModel
    
    init(viewModel: StatusTableViewModel) {
        self.viewModel = viewModel
        
        self.wrapped = WrappedStatusTableViewController(
            alertPermissionsChecker: viewModel.alertPermissionsChecker,
            alertMuter: viewModel.alertMuter,
            deviceDataManager: viewModel.deviceDataManager,
            onboardingManager: viewModel.onboardingManager,
            supportManager: viewModel.supportManager,
            testingScenariosManager: viewModel.testingScenariosManager,
            settingsManager: viewModel.settingsManager,
            temporaryPresetsManager: viewModel.temporaryPresetsManager,
            loopDataManager: viewModel.loopDataManager,
            diagnosticReportGenerator: viewModel.diagnosticReportGenerator,
            simulatedData: viewModel.simulatedData,
            analyticsServicesManager: viewModel.analyticsServicesManager,
            servicesManager: viewModel.servicesManager,
            carbStore: viewModel.carbStore,
            doseStore: viewModel.doseStore,
            criticalEventLogExportManager: viewModel.criticalEventLogExportManager,
            bluetoothStateManager: viewModel.bluetoothStateManager,
            statusTableViewModel: viewModel
        )
    }

    var body: some View {
        wrappedView
            .ignoresSafeArea(edges: .bottom)
            .onChange(of: viewModel.temporaryPresetsManager.activeOverride) { _, _ in
                Task {
                    await viewController.reloadData(animated: true)
                }
            }
            .sheet(item: $viewModel.pendingPreset) { preset in
                // This is the active preset; edit disabled
                PresetDetentView(preset: preset, roundBasalRate: viewModel.loopDataManager.deliveryDelegate?.roundBasalRate, didTapEdit: { })
                    .accessibilityIdentifier("bar_Presets")
            }
            .toolbar {
                if !isLandscape {
                    if #available(iOS 26, *) {
                        ToolbarItemGroup(placement: .bottomBar) {
                            carbTab
                            Spacer()
                            bolusTab
                            Spacer()
                            presetsTab
                            Spacer()
                            settingsTab
                        }
                    } else {
                        ToolbarItem(placement: .bottomBar) {
                            HStack {
                                carbTab
                                bolusTab
                                presetsTab
                                settingsTab
                            }
                        }
                    }
                }
            }
            .toolbar(isLandscape ? .hidden : .visible, for: .bottomBar)
            .toolbarBackground(.visible, for: .bottomBar)
    }
    
    var carbTab: some View {
        Button {
            viewController.userTappedAddCarbs()
        } label: {
            VStack(spacing: 0) {
                Image("carbs")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.carbs)

                Text("Add Carbs")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("statusTableViewControllerCarbsButton")
    }
    
    var bolusTab: some View {
        Button {
            viewController.presentBolusScreen()
        } label: {
            VStack(spacing: 0) {
                Image("bolus")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.insulin)
                
                Text("Bolus")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("statusTableViewControllerBolusButton")
    }
    
    var presetsTab: some View {
        Button {
            viewController.presentPresets()
        } label: {
            VStack(spacing: 0) {
                Image(viewModel.temporaryPresetsManager.activeOverride != nil ? "presets-selected" : "presets")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.presets)
                    .animation(.default, value: viewModel.temporaryPresetsManager.activeOverride)
                
                Text("Presets")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("statusTableViewPresetsButton")
    }
    
    var settingsTab: some View {
        Button {
            viewController.presentSettings()
        } label: {
            VStack(spacing: 0) {
                Image("settings")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color.secondary)
                
                Text("Settings")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("statusTableViewControllerSettingsButton")
    }
}
