//
//  LoggingManager.swift
//  Loop
//
//  Created by Darin Krauss on 6/13/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//


import os.log
import LoopKit


final class LoggingManager: Logging {

    private let servicesManager: ServicesManager

    private var logging: [Logging]

    init(servicesManager: ServicesManager) {
        self.servicesManager = servicesManager

        self.logging = servicesManager.services.compactMap({ $0 as? Logging })

        servicesManager.addObserver(self)
    }

    func log (_ message: StaticString, subsystem: String, category: String, type: OSLogType, _ args: [CVarArg]) {
        logging.forEach { $0.log(message, subsystem: subsystem, category: category, type: type, args) }
    }
}


extension LoggingManager: ServicesManagerObserver {

    func servicesManagerDidUpdate(services: [Service]) {
        logging = servicesManager.services.compactMap({ $0 as? Logging })
    }

}
