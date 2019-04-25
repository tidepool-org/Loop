//
//  LocalTestingScenariosManager.swift
//  Loop
//
//  Created by Michael Pangburn on 4/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopTestingKit


final class LocalTestingScenariosManager: TestingScenariosManager, DirectoryObserver {
    unowned let deviceManager: DeviceDataManager
    let _log: CategoryLogger

    private let fileManager = FileManager.default
    private let scenariosSource: URL
    private var directoryObservationToken: DirectoryObservationToken?

    private var scenarioURLs: [URL] = []
    var _activeScenarioURL: URL?
    var _activeScenario: TestingScenario?

    weak var delegate: TestingScenariosManagerDelegate? {
        didSet {
            delegate?.testingScenariosManager(self, didUpdateScenarioURLs: scenarioURLs)
        }
    }

    init(deviceManager: DeviceDataManager) {
        assertDebugOnly()

        self.deviceManager = deviceManager
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.scenariosSource = documentsDirectory.appendingPathComponent("scenarios")
        self._log = deviceManager.logger.forCategory("TestingScenarioManager")

        _log.debug("Place testing scenarios in \(scenariosSource.path)")
        if !fileManager.fileExists(atPath: scenariosSource.path) {
            do {
                try fileManager.createDirectory(at: scenariosSource, withIntermediateDirectories: false)
            } catch {
                _log.error(error)
            }
        }

        directoryObservationToken = observeDirectory(at: scenariosSource, updatingWith: reloadScenarioURLs)
        reloadScenarioURLs()
    }

    func _fetchScenario(from url: URL, completion: (Result<TestingScenario, Error>) -> Void) {
        let result = Result(catching: { try TestingScenario(source: url) })
        completion(result)
    }

    private func reloadScenarioURLs() {
        do {
            let scenarioURLs = try fileManager.contentsOfDirectory(at: scenariosSource, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            self.scenarioURLs = scenarioURLs
            delegate?.testingScenariosManager(self, didUpdateScenarioURLs: scenarioURLs)
            _log.debug("Reloaded scenario URLs")
        } catch {
            _log.error(error)
        }
    }
}
