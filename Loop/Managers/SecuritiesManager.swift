//
//  SecuritiesManager.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2023-09-06.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import LoopCore
import Combine

class SecuritiesManager: SecurityProvider {

    private let pluginManager: PluginManager
    
    private let servicesManager: ServicesManager
    
    private var securities = [Security]()

    private let securitiesLock = UnfairLock()

    @PersistedProperty(key: "Securities")
    var rawSecurities: [Security.RawValue]?
    
    init(pluginManager: PluginManager,
         servicesManager: ServicesManager)
    {
        self.pluginManager = pluginManager
        self.servicesManager = servicesManager
        restoreState()
    }

    public var availableSecurityIdentifiers: [String] {
        return pluginManager.availableSecurityIdentifiers
    }

    func security(withIdentifier identifier: String) -> Security? {
        for security in securities {
            if security.pluginIdentifier == identifier {
                return security
            }
        }
        
        return setupSecurity(withIdentifier: identifier)
    }
    
    func setupSecurity(withIdentifier identifier: String) -> Security? {
        guard let security = pluginManager.getSecurityByIdentifier(identifier) else { return nil }
        security.initializationComplete(for: servicesManager.activeServices)
        addActiveSecurity(security)
        return security
    }
    
    private func securityFromRawValue(_ rawValue: Security.RawValue) -> Security? {
        guard let identifier = rawValue["securityIdentifier"] as? String else {
            return nil
        }

        return setupSecurity(withIdentifier: identifier)
    }
    
    public var activeSecurities: [Security] {
        return securitiesLock.withLock { securities }
    }

    public func addActiveSecurity(_ security: Security) {
        securitiesLock.withLock {
            securities.append(security)
            saveState()
        }
    }

    public func removeActiveSecurity(_ security: Security) {
        securitiesLock.withLock {
            securities.removeAll { $0.pluginIdentifier == security.pluginIdentifier }
            saveState()
        }
    }
    
    private func saveState() {
        rawSecurities = securities.compactMap { $0.rawValue }
    }
    
    private func restoreState() {
        let rawServices = rawSecurities ?? []
        rawServices.forEach { rawValue in
            if let security = securityFromRawValue(rawValue) {
                security.initializationComplete(for: servicesManager.activeServices)
                securities.append(security)
            }
        }
    }
}
