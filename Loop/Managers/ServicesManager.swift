//
//  ServicesManager.swift
//  Loop
//
//  Created by Darin Krauss on 5/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI

protocol ServicesManagerObserver {

    /// The service manager updated the list of active services.
    ///
    /// - Parameter activeServices: The list of active services.
    func servicesManagerDidUpdate(activeServices: [Service])

}

class ServicesManager {

    private let queue = DispatchQueue(label: "com.loopkit.ServicesManagerQueue", qos: .utility)

    private let pluginManager: PluginManager

    private var services = [Service]()

    private let servicesLock = UnfairLock()

    private var observers = WeakSet<ServicesManagerObserver>()

    private let observersLock = UnfairLock()

    init(pluginManager: PluginManager) {
        self.pluginManager = pluginManager

        restoreState()
    }

    public var availableServices: [AvailableDevice] {
        return pluginManager.availableServices + availableStaticServices
    }

    func serviceUITypeByIdentifier(_ identifier: String) -> ServiceUI.Type? {
        return pluginManager.getServiceTypeByIdentifier(identifier) ?? staticServicesByIdentifier[identifier] as? ServiceUI.Type
    }

    private func serviceTypeFromRawValue(_ rawValue: Service.RawStateValue) -> Service.Type? {
        guard let identifier = rawValue["serviceIdentifier"] as? String else {
            return nil
        }

        return serviceUITypeByIdentifier(identifier)
    }

    private func serviceFromRawValue(_ rawValue: Service.RawStateValue) -> Service? {
        guard let serviceType = serviceTypeFromRawValue(rawValue),
            let rawState = rawValue["state"] as? Service.RawStateValue else {
            return nil
        }

        return serviceType.init(rawState: rawState)
    }

    public var activeServices: [Service] {
        return servicesLock.withLock({ services })
    }

    public func addActiveService(_ service: Service) {
        servicesLock.withLock {
            services.append(service)
            saveState()
        }
        notifyObservers()
    }

    public func updateActiveService(_ service: Service) {
        servicesLock.withLock {
            saveState()
        }
        notifyObservers()
    }

    public func removeActiveService(_ service: Service) {
        servicesLock.withLock {
            services.removeAll { $0.serviceIdentifier == service.serviceIdentifier }
            saveState()
        }
        notifyObservers()
    }

    private func saveState() {
        UserDefaults.appGroup?.servicesState = services.compactMap { $0.rawValue }
    }

    private func restoreState() {
        services = UserDefaults.appGroup?.servicesState.compactMap { serviceFromRawValue($0) } ?? []
    }

    public func addObserver(_ observer: ServicesManagerObserver) {
        observersLock.withLock {
            observers.insert(observer)
            return
        }
    }

    public func removeObserver(_ observer: ServicesManagerObserver) {
        observersLock.withLock {
            observers.remove(observer)
            return
        }
    }

    private func notifyObservers() {
        for observer in observersLock.withLock({ observers }) {
            observer.servicesManagerDidUpdate(activeServices: activeServices)
        }
    }

}
