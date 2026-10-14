//
//  InsulinDeliveryLogViewModelTests.swift
//  LoopTests
//
//  Created by Martin Stachon on 2026-10-14.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopAlgorithm
import LoopKit
@testable import Loop

@MainActor
final class InsulinDeliveryLogViewModelTests: XCTestCase {

    private let now = Date()
    private lazy var since = now.addingTimeInterval(.days(-1))

    private let targetRange = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 100)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 110)

    private func makeSavedPreset(named name: String) -> TemporaryPreset {
        TemporaryPreset(
            id: "saved-preset-\(name)",
            symbol: .emoji("🏃"),
            name: name,
            settings: TemporaryPresetSettings(targetRange: targetRange, insulinNeedsScaleFactor: 0.8),
            duration: .finite(.hours(1))
        )
    }

    private func makeOverride(context: TemporaryScheduleOverride.Context, startDate: Date, duration: TimeInterval) -> TemporaryScheduleOverride {
        TemporaryScheduleOverride(
            context: context,
            settings: TemporaryPresetSettings(targetRange: targetRange, insulinNeedsScaleFactor: 0.8),
            startDate: startDate,
            duration: .finite(duration),
            enactTrigger: .local,
            syncIdentifier: UUID()
        )
    }

    private func makeHistory(recording overrides: TemporaryScheduleOverride...) -> TemporaryScheduleOverrideHistory {
        let history = TemporaryScheduleOverrideHistory()
        overrides.forEach { history.recordOverride($0, at: $0.startDate) }
        return history
    }

    func testEndedSavedPresetKeepsNameAndIconRecordedAtActivation() {
        let override = makeOverride(context: .preset(makeSavedPreset(named: "Old Name")), startDate: now.addingTimeInterval(.hours(-3)), duration: .hours(1))

        let events = InsulinDeliveryLogViewModel.presetEvents(from: makeHistory(recording: override), since: since, now: now)

        XCTAssertEqual(events.map(\.type), [
            .preset(.enabled, icon: .emoji("🏃"), name: "Old Name"),
            .preset(.disabled, icon: .emoji("🏃"), name: "Old Name")
        ])
        XCTAssertEqual(events.map(\.date), [override.startDate, override.actualEndDate])
    }

    func testEndedSingleUsePresetIsListed() {
        let override = makeOverride(context: .custom, startDate: now.addingTimeInterval(.hours(-3)), duration: .hours(1))

        let events = InsulinDeliveryLogViewModel.presetEvents(from: makeHistory(recording: override), since: since, now: now)

        XCTAssertEqual(events.map(\.type), [
            .preset(.enabled, icon: nil, name: "Single Use Preset"),
            .preset(.disabled, icon: nil, name: "Single Use Preset")
        ])
    }

    func testActivityStartedFromPresetListKeepsActivityNameAndIcon() {
        let jogging = ActivityPreset.ActivityType.jogging
        let override = SelectablePreset.activity(ActivityPreset(activityType: jogging, preset: jogging.completeDefaultPreset))
            .createOverride(beginningAt: now.addingTimeInterval(.hours(-3)))

        let events = InsulinDeliveryLogViewModel.presetEvents(from: makeHistory(recording: override), since: since, now: now)

        XCTAssertEqual(events.map(\.type), [
            .preset(.enabled, icon: jogging.symbol, name: jogging.name),
            .preset(.disabled, icon: jogging.symbol, name: jogging.name)
        ])
    }

    func testActivePresetHasNoDisabledEvent() {
        let override = makeOverride(context: .custom, startDate: now.addingTimeInterval(.minutes(-30)), duration: .hours(1))

        let events = InsulinDeliveryLogViewModel.presetEvents(from: makeHistory(recording: override), since: since, now: now)

        XCTAssertEqual(events.map(\.type), [.preset(.enabled, icon: nil, name: "Single Use Preset")])
    }

    func testPresetCancelledBeforeItStartedIsNotListed() {
        let override = makeOverride(context: .custom, startDate: now.addingTimeInterval(.hours(1)), duration: .hours(1))
        let history = TemporaryScheduleOverrideHistory()
        history.recordOverride(override, at: now)
        history.recordOverride(nil, at: now)

        let events = InsulinDeliveryLogViewModel.presetEvents(from: history, since: since, now: now)

        XCTAssertEqual(history.recentEvents.map(\.override.actualEnd), [.deleted])
        XCTAssertTrue(events.isEmpty)
    }

    func testOnlyPresetsEndingWithinTheLogWindowAreListed() {
        let endedBeforeWindow = makeOverride(context: .preset(makeSavedPreset(named: "Before")), startDate: since.addingTimeInterval(.hours(-2)), duration: .hours(1))
        let endedAtWindowStart = makeOverride(context: .preset(makeSavedPreset(named: "At Start")), startDate: since.addingTimeInterval(.minutes(-30)), duration: .minutes(30))

        let events = InsulinDeliveryLogViewModel.presetEvents(from: makeHistory(recording: endedBeforeWindow, endedAtWindowStart), since: since, now: now)

        XCTAssertEqual(events.map(\.type), [
            .preset(.enabled, icon: .emoji("🏃"), name: "At Start"),
            .preset(.disabled, icon: .emoji("🏃"), name: "At Start")
        ])
    }
}
