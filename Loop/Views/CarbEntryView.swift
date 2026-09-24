//
//  CarbEntryView.swift
//  Loop
//
//  Created by Noah Brauner on 7/19/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI

struct CarbEntryView: View, HorizontalSizeClassOverride {
    private enum Field: Hashable {
        case amountConsumed
    }

    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.dismissAction) private var dismiss
    @Environment(\.guidanceColors) private var guidanceColors

    @ObservedObject var viewModel: CarbEntryViewModel
        
    @FocusState private var focusedField: Field?
    @State private var expandedRow: Row?
    
    @State private var showHowAbsorptionTimeWorks = false
    @State private var showAddFavoriteFood = false
    @State private var showFavoriteFoodInsights = false
    
    private let isNewEntry: Bool

    init(viewModel: CarbEntryViewModel) {
        isNewEntry = viewModel.originalCarbEntry == nil
        self.viewModel = viewModel
    }
    
    var body: some View {
        navigationContent
            .sheet(isPresented: $showAddFavoriteFood, onDismiss: clearExpandedRow) {
                FavoriteFoodAddEditView(
                    carbsQuantity: viewModel.carbsQuantity,
                    foodType: viewModel.effectiveFoodType,
                    absorptionTime: viewModel.absorptionTime,
                    onSave: onFavoriteFoodSave(_:)
                )
            }
            .sheet(isPresented: $showHowAbsorptionTimeWorks) {
                HowAbsorptionTimeWorksView()
            }
            .sheet(isPresented: $showFavoriteFoodInsights) {
                if let food = viewModel.selectedFavoriteFood {
                    FavoriteFoodInsightsView(viewModel: FavoriteFoodInsightsViewModel(delegate: viewModel.delegate, food: food))
                }
            }
    }

    @ViewBuilder
    private var navigationContent: some View {
        if isNewEntry {
            NavigationView {
                let title = NSLocalizedString("carb-entry-title-add", value: "Add Carb Entry", comment: "The title of the view controller to create a new carb entry")
                content
                    .navigationBarTitle(title, displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            dismissButton
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
        else {
            content
        }
    }
    
    private var content: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
               if let currentOverride = viewModel.currentOverride {
                   ActivePresetBanner(override: currentOverride)
                       .padding(.bottom, 8)
               }
                
                warningsCard

                mainCard
                    .padding(.top, 8)

                if isNewEntry, FeatureFlags.allowExperimentalFeatures {
                    favoriteFoodsCard
                        .padding(.top, 8)
                }
                
                if viewModel.selectedFavoriteFoodLastEaten != nil, FeatureFlags.allowExperimentalFeatures {
                    FavoriteFoodInsightsCardView(
                        showFavoriteFoodInsights: $showFavoriteFoodInsights,
                        foodName: viewModel.selectedFavoriteFood?.name,
                        lastEatenDate: viewModel.selectedFavoriteFoodLastEaten,
                        relativeDateFormatter: viewModel.relativeDateFormatter
                    )
                    .padding(.top, 8)
                }
                
                let isBolusViewActive = Binding(get: { viewModel.bolusViewModel != nil }, set: { _, _ in viewModel.bolusViewModel = nil })
                NavigationLink(destination: bolusView, isActive: isBolusViewActive) {
                    EmptyView()
                }
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibility(hidden: true)
            }
        }
        .initialFocus($focusedField, equals: .amountConsumed, when: viewModel.shouldBeginEditingQuantity)
        .inputForm(focus: $focusedField)
        .actionAreaInset {
            continueActionButton
        }
        .onChange(of: focusedField) { _, field in
            if field != nil {
                expandedRow = nil
            }
        }
        .onDisappear {
            expandedRow = nil
        }
        .alert(item: $viewModel.alert, content: alert(for:))
    }
    
    private var mainCard: some View {
        VStack(spacing: 10) {
            let timeFocused = focusBinding(for: .time)
            let foodTypeFocused = focusBinding(for: .foodType)
            let absorptionTimeFocused = focusBinding(for: .absorptionTime)
            // Food type row shows an x button next to favorite food chip that clears favorite food by setting this binding to nil
            let selectedFavoriteFoodBinding = Binding(
                get: { viewModel.selectedFavoriteFood },
                set: { food in
                    guard food == nil else { return }
                    viewModel.selectedFavoriteFoodIndex = -1
                }
            )
            
            CarbQuantityRow(quantity: $viewModel.carbsQuantity, focus: $focusedField, equals: .amountConsumed, title: NSLocalizedString("Amount Consumed", comment: "Label for carb quantity entry row on carb entry screen"), preferredCarbUnit: viewModel.preferredCarbUnit)

            CardSectionDivider()
            
            DatePickerRow(date: $viewModel.time, isFocused: timeFocused, minimumDate: viewModel.minimumDate, maximumDate: viewModel.maximumDate)

            CardSectionDivider()
            
            FoodTypeRow(selectedFavoriteFood: selectedFavoriteFoodBinding, foodType: $viewModel.foodType, absorptionTime: $viewModel.absorptionTime, selectedDefaultAbsorptionTimeEmoji: $viewModel.selectedDefaultAbsorptionTimeEmoji, usesCustomFoodType: $viewModel.usesCustomFoodType, absorptionTimeWasEdited: $viewModel.absorptionTimeWasEdited, isFocused: foodTypeFocused, showClearFavoriteFoodButton: !isNewEntry, defaultAbsorptionTimes: viewModel.defaultAbsorptionTimes)

            CardSectionDivider()
            
            AbsorptionTimePickerRow(absorptionTime: $viewModel.absorptionTime, isFocused: absorptionTimeFocused, validDurationRange: viewModel.absorptionRimesRange, showHowAbsorptionTimeWorks: $showHowAbsorptionTimeWorks)
                .padding(.bottom, 2)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(CardBackground())
        .padding(.horizontal)
    }

    private func focusBinding(for row: Row) -> Binding<Bool> {
        Binding(
            get: { expandedRow == row },
            set: { focused in
                if focused {
                    focusedField = nil
                    expandedRow = row
                } else if expandedRow == row {
                    expandedRow = nil
                }
            }
        )
    }
    
    @ViewBuilder
    private var bolusView: some View {
        if let viewModel = viewModel.bolusViewModel {
            BolusEntryView(viewModel: viewModel)
                .environmentObject(displayGlucosePreference)
                .environment(\.dismissAction, dismiss)
                .environment(\.guidanceColors, guidanceColors)
        }
    }
    
    private func clearExpandedRow() {
        self.focusedField = nil
        self.expandedRow = nil
    }
}

// MARK: - Warnings & Alerts
extension CarbEntryView {
    private var warningsCard: some View {
        ForEach(Array(viewModel.warnings).sorted(by: { $0.priority < $1.priority })) { warning in
            warningView(for: warning)
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(CardBackground())
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }
    
    private func warningView(for warning: CarbEntryViewModel.Warning) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(triangleColor(for: warning))
            
            Text(warningText(for: warning))
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func triangleColor(for warning: CarbEntryViewModel.Warning) -> Color {
        switch warning {
        case .entryIsMissedMeal:
            return .critical
        case .glucoseRisingRapidly:
            return .critical
        }
    }
    
    private func warningText(for warning: CarbEntryViewModel.Warning) -> String {
        switch warning {
        case .entryIsMissedMeal:
            return NSLocalizedString("Loop has detected an missed meal and estimated its size. Edit the carb amount to match the amount of any carbs you may have eaten.", comment: "Warning displayed when user is adding a meal from an missed meal notification")
        case .glucoseRisingRapidly:
            return NSLocalizedString("Your glucose is rapidly rising. Check that any carbs you've eaten were logged. If you logged carbs, check that the time you entered lines up with when you started eating.", comment: "Warning to ensure the carb entry is accurate")
        }
    }
    
    private func alert(for alert: CarbEntryViewModel.Alert) -> SwiftUI.Alert {
        switch alert {
        case .maxQuantityExceded:
            let message = String(
                format: NSLocalizedString("The maximum allowed amount is %@ grams.", comment: "Alert body displayed for quantity greater than max (1: maximum quantity in grams)"),
                NumberFormatter.localizedString(from: NSNumber(value: viewModel.maxCarbEntryQuantity.doubleValue(for: viewModel.preferredCarbUnit)), number: .none)
            )
            let okMessage = NSLocalizedString("com.loudnate.LoopKit.errorAlertActionTitle", value: "OK", comment: "The title of the action used to dismiss an error alert")
            return SwiftUI.Alert(
                title: Text("Large Meal Entered", comment: "Title of the warning shown when a large meal was entered"),
                message: Text(message),
                dismissButton: .cancel(Text(okMessage), action: viewModel.clearAlert)
            )
        case .warningQuantityValidation:
            let message = String(
                format: NSLocalizedString("Did you intend to enter %1$@ grams as the amount of carbohydrates for this meal?", comment: "Alert body when entered carbohydrates is greater than threshold (1: entered quantity in grams)"),
                NumberFormatter.localizedString(from: NSNumber(value: viewModel.carbsQuantity ?? 0), number: .none)
            )
            return SwiftUI.Alert(
                title: Text("Large Meal Entered", comment: "Title of the warning shown when a large meal was entered"),
                message: Text(message),
                primaryButton: .default(Text("No, edit amount", comment: "The title of the action used when rejecting the the amount of carbohydrates entered."), action: viewModel.clearAlert),
                secondaryButton: .cancel(Text("Yes", comment: "The title of the action used when confirming entered amount of carbohydrates."), action: viewModel.clearAlertAndContinueToBolus)
            )
        }
    }
}

// MARK: - Favorite Foods Card
extension CarbEntryView {
    private var favoriteFoodsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FAVORITE FOODS")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 26)
            
            VStack(spacing: 10) {
                if !viewModel.favoriteFoods.isEmpty {
                    VStack {
                        HStack {
                            Text("Choose Favorite:")
                            
                            let selectedFavorite = favoritedFoodTextFromIndex(viewModel.selectedFavoriteFoodIndex)
                            Text(selectedFavorite)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        
                        if expandedRow == .favoriteFoodSelection {
                            Picker("", selection: $viewModel.selectedFavoriteFoodIndex) {
                                ForEach(-1..<viewModel.favoriteFoods.count, id: \.self) { index in
                                    Text(favoritedFoodTextFromIndex(index))
                                        .tag(index)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                    }
                    .onTapGesture {
                        withAnimation {
                            if expandedRow == .favoriteFoodSelection {
                                expandedRow = nil
                            }
                            else {
                                focusedField = nil
                                expandedRow = .favoriteFoodSelection
                            }
                        }
                    }
                    
                    if viewModel.selectedFavoriteFood == nil {
                        CardSectionDivider()
                    }
                }
                
                if viewModel.selectedFavoriteFood == nil {
                    Button(action: saveAsFavoriteFood) {
                        Text("Save as favorite food")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.saveFavoriteFoodButtonDisabled)
                    .accessibilityIdentifier("button_SaveAsFavoriteFood")
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(CardBackground())
            .padding(.horizontal)
            .onChange(of: viewModel.selectedFavoriteFoodIndex, perform: collapseFavoriteFoodsRowIfNeeded(_:))
        }
    }
    
    private func collapseFavoriteFoodsRowIfNeeded(_ newIndex: Int) {
        if newIndex != -1 {
            withAnimation {
                clearExpandedRow()
            }
        }
    }
    
    private func favoritedFoodTextFromIndex(_ index: Int) -> String {
        if index == -1 {
            return "None"
        }
        else {
            let food = viewModel.favoriteFoods[index]
            return "\(food.name) \(food.foodType)"
        }
    }
    
    private func saveAsFavoriteFood() {
        clearExpandedRow()
        self.showAddFavoriteFood = true
    }
    
    private func onFavoriteFoodSave(_ food: NewFavoriteFood) {
        clearExpandedRow()
        self.showAddFavoriteFood = false
        viewModel.onFavoriteFoodSave(food)
    }
}

// MARK: - Other UI Elements
extension CarbEntryView {
    private var dismissButton: some View {
        Button(action: dismiss) {
            Text("Cancel")
        }
    }
    
    private var continueActionButton: some View {
        Button(action: {
            clearExpandedRow()
            viewModel.continueToBolus()
        }) {
            Text("Continue")
        }
        .buttonStyle(ActionButtonStyle())
        .disabled(viewModel.continueButtonDisabled)
        .accessibilityIdentifier("button_Continue")
    }
    
}

extension CarbEntryView {
    enum Row {
        case time, foodType, absorptionTime, favoriteFoodSelection
    }
}
