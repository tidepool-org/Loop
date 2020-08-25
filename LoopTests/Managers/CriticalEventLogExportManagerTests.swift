//
//  CriticalEventLogExportManagerTests.swift
//  LoopTests
//
//  Created by Darin Krauss on 8/27/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import Foundation
import LoopKit
@testable import Loop

fileprivate let now = ISO8601DateFormatter().date(from: "2020-03-11T12:13:14-0700")!  // Explicitly chosen near DST change

class CriticalEventLogExportManagerTests: XCTestCase {
    var fileManager: FileManager!
    var logs: [MockCriticalEventLog]!
    var directory: URL!
    var historicalDuration: TimeInterval!
    var manager: CriticalEventLogExportManager!
    var delegate: MockCriticalEventLogExporterDelegate!
    var url: URL!

    override func setUp() {
        super.setUp()

        fileManager = FileManager.default
        logs = [MockCriticalEventLog(name: "One", estimatedDuration: 1),
                MockCriticalEventLog(name: "Two", estimatedDuration: 2),
                MockCriticalEventLog(name: "Three", estimatedDuration: 3)]
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        historicalDuration = .days(5)
        manager = CriticalEventLogExportManager(logs: logs, directory: directory, historicalDuration: historicalDuration, fileManager: fileManager)
        delegate = MockCriticalEventLogExporterDelegate()
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? fileManager.removeItem(atPath: url.path)
        try? fileManager.removeItem(atPath: directory.path)

        url = nil
        delegate = nil
        manager = nil
        historicalDuration = nil
        directory = nil
        logs = nil
        fileManager = nil

        super.tearDown()
    }

    func testNextExportHistoricalDateWhenUpToDate() {
        XCTAssertNoThrow(try fileManager.createDirectory(at: directory, withIntermediateDirectories: true))
        XCTAssertTrue(fileManager.createFile(atPath: directory.appendingPathComponent("20200310T000000Z.zip").path, contents: nil))

        XCTAssertEqual(manager.nextExportHistoricalDate(now: now), ISO8601DateFormatter().date(from: "2020-03-12T00:00:00Z"))
    }

    func testNextExportHistoricalDateWhenNotUpToDate() {
        XCTAssertNoThrow(try fileManager.createDirectory(at: directory, withIntermediateDirectories: true))
        XCTAssertTrue(fileManager.createFile(atPath: directory.appendingPathComponent("20200309T000000Z.zip").path, contents: nil))

        XCTAssertEqual(manager.nextExportHistoricalDate(now: now), ISO8601DateFormatter().date(from: "2020-03-11T19:13:14Z"))
    }

    func testRetryExportHistoricalDate() {
        XCTAssertEqual(manager.retryExportHistoricalDate(now: now), ISO8601DateFormatter().date(from: "2020-03-11T20:13:14Z"))
    }

    func testExport() {
        logs.forEach { $0.exportExpectation = self.expectation(description: $0.name, expectedFulfillmentCount: 5) }

        var exporter = manager.createExporter(to: url)
        exporter.delegate = delegate

        XCTAssertNil(exporter.export(now: now))

        XCTAssertFalse(exporter.isCancelled)
        XCTAssertTrue(fileManager.isReadableFile(atPath: url.path))
        XCTAssertFalse(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200306T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200307T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200308T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200309T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200310T000000Z.zip").path))
        XCTAssertFalse(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200311T000000Z.zip").path))
        XCTAssertEqual(delegate.progress!, 1.0, accuracy: 0.0001)

        wait(for: logs.map { $0.exportExpectation! }, timeout: 0)
    }

    func testExportPartial() {
        logs.forEach { $0.exportExpectation = self.expectation(description: $0.name, expectedFulfillmentCount: 3) }

        XCTAssertNoThrow(try fileManager.createDirectory(at: directory, withIntermediateDirectories: true))
        XCTAssertTrue(fileManager.createFile(atPath: directory.appendingPathComponent("20200307T000000Z.zip").path, contents: nil))
        XCTAssertTrue(fileManager.createFile(atPath: directory.appendingPathComponent("20200308T000000Z.zip").path, contents: nil))

        var exporter = manager.createExporter(to: url)
        exporter.delegate = delegate

        XCTAssertNil(exporter.export(now: now))

        XCTAssertFalse(exporter.isCancelled)
        XCTAssertTrue(fileManager.isReadableFile(atPath: url.path))
        XCTAssertFalse(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200306T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200309T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200310T000000Z.zip").path))
        XCTAssertFalse(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200311T000000Z.zip").path))
        XCTAssertEqual(delegate.progress!, 1.0, accuracy: 0.0001)

        wait(for: logs.map { $0.exportExpectation! }, timeout: 0)
    }

    func testExportCancelled() {
        let exporter = manager.createExporter(to: url)
        exporter.cancel()

        XCTAssertEqual(exporter.export(now: now) as? CriticalEventLogError, CriticalEventLogError.cancelled)

        XCTAssertTrue(exporter.isCancelled)
    }

    func testExportHistorical() {
        logs.forEach { $0.exportExpectation = self.expectation(description: $0.name, expectedFulfillmentCount: 4) }

        var exporter = manager.createHistoricalExporter()
        exporter.delegate = delegate

        XCTAssertNil(exporter.export(now: now))

        XCTAssertFalse(exporter.isCancelled)
        XCTAssertFalse(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200306T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200307T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200308T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200309T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200310T000000Z.zip").path))
        XCTAssertFalse(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200311T000000Z.zip").path))
        XCTAssertEqual(delegate.progress!, 1.0, accuracy: 0.0001)

        wait(for: logs.map { $0.exportExpectation! }, timeout: 0)
    }

    func testExportHistoricalPartial() {
        logs.forEach { $0.exportExpectation = self.expectation(description: $0.name, expectedFulfillmentCount: 2) }

        XCTAssertNoThrow(try fileManager.createDirectory(at: directory, withIntermediateDirectories: true))
        XCTAssertTrue(fileManager.createFile(atPath: directory.appendingPathComponent("20200307T000000Z.zip").path, contents: nil))
        XCTAssertTrue(fileManager.createFile(atPath: directory.appendingPathComponent("20200308T000000Z.zip").path, contents: nil))

        var exporter = manager.createHistoricalExporter()
        exporter.delegate = delegate

        XCTAssertNil(exporter.export(now: now))

        XCTAssertFalse(exporter.isCancelled)
        XCTAssertFalse(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200306T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200309T000000Z.zip").path))
        XCTAssertTrue(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200310T000000Z.zip").path))
        XCTAssertFalse(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200311T000000Z.zip").path))
        XCTAssertEqual(delegate.progress!, 1.0, accuracy: 0.0001)

        wait(for: logs.map { $0.exportExpectation! }, timeout: 0)
    }

    func testExportHistoricalPurge() {
        XCTAssertNoThrow(try fileManager.createDirectory(at: directory, withIntermediateDirectories: true))
        XCTAssertTrue(fileManager.createFile(atPath: directory.appendingPathComponent("20200305T000000Z.zip").path, contents: nil))
        XCTAssertTrue(fileManager.createFile(atPath: directory.appendingPathComponent("20200306T000000Z.zip").path, contents: nil))

        let exporter = manager.createHistoricalExporter()

        XCTAssertNil(exporter.export(now: now))

        XCTAssertFalse(exporter.isCancelled)
        XCTAssertFalse(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200305T000000Z.zip").path))
        XCTAssertFalse(fileManager.isReadableFile(atPath: directory.appendingPathComponent("20200306T000000Z.zip").path))
    }

    func testExportHistoricalCancelled() {
        let exporter = manager.createHistoricalExporter()
        exporter.cancel()

        XCTAssertEqual(exporter.export(now: now) as? CriticalEventLogError, CriticalEventLogError.cancelled)

        XCTAssertTrue(exporter.isCancelled)
    }
}

class MockCriticalEventLog: CriticalEventLog {
    var name: String
    var estimatedDuration: TimeInterval
    var error: Error?
    var exportEstimatedDurationExpectation: XCTestExpectation?
    var exportExpectation: XCTestExpectation?

    init(name: String, estimatedDuration: TimeInterval) {
        self.name = name
        self.estimatedDuration = estimatedDuration
    }

    var exportName: String { name }

    func exportEstimatedDuration(startDate: Date, endDate: Date?) -> Result<TimeInterval, Error> {
        exportEstimatedDurationExpectation?.fulfill()

        if let error = error {
            return .failure(error)
        }

        let days = (endDate ?? now).timeIntervalSince(startDate).days.rounded(.down)
        return .success(estimatedDuration * days)
    }

    func export(startDate: Date, endDate: Date, to stream: OutputStream, progressor: EstimatedDurationProgressor) -> Error? {
        exportExpectation?.fulfill()

        guard !progressor.isCancelled else {
            return CriticalEventLogError.cancelled
        }

        if let error = error {
            return error
        }

        do {
            try stream.write(name)
        } catch let error {
            return error
        }

        progressor.didProgress(for: estimatedDuration)
        return nil
    }
}

class MockCriticalEventLogExporterDelegate: CriticalEventLogExporterDelegate {
    var progress: Double?

    func exportDidProgress(_ progress: Double) {
        self.progress = progress
    }
}

fileprivate struct MockError: Error, Equatable {}

fileprivate extension XCTestCase {
    func expectation(description: String, expectedFulfillmentCount: Int) -> XCTestExpectation {
        let expectation = self.expectation(description: description)
        expectation.expectedFulfillmentCount = expectedFulfillmentCount
        return expectation
    }
}
