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

    /// The service manager update the list of available services.
    ///
    /// - Parameter services: The list of available services
    func servicesManagerDidUpdate(services: [Service])

}


class ServicesManager {

    private let queue = DispatchQueue(label: "com.loopkit.ServicesManagerQueue", qos: .utility)

    private let pluginManager: PluginManager

    private let lock = UnfairLock()

    private var observers = WeakSet<ServicesManagerObserver>()

    var services: [Service]! {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            setupServices()
            UserDefaults.appGroup?.servicesState = services.compactMap { $0.rawValue }
            notifyObservers()
        }
    }

    init(pluginManager: PluginManager) {
        self.pluginManager = pluginManager
        self.services = UserDefaults.appGroup?.servicesState.compactMap { serviceFromRawValue($0) } ?? []
        setupServices()
    }

    var availableServices: [AvailableDevice] {
        return pluginManager.availableServices + availableStaticServices
    }

    func serviceUITypeByIdentifier(_ identifier: String) -> ServiceUI.Type? {
        return pluginManager.getServiceTypeByIdentifier(identifier) ?? staticServicesByIdentifier[identifier] as? ServiceUI.Type
    }

    private func serviceTypeFromRawValue(_ rawValue: Service.RawStateValue) -> Service.Type? {
        guard let identifier = rawValue["managerIdentifier"] as? String else {
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

    private func setupServices() {
        dispatchPrecondition(condition: .onQueue(.main))

        services.forEach { service in
            service.serviceDelegate = self
            service.delegateQueue = queue
        }
    }

    public func addObserver(_ observer: ServicesManagerObserver) {
        lock.withLock {
            observers.insert(observer)
            return
        }
    }

    public func removeObserver(_ observer: ServicesManagerObserver) {
        lock.withLock {
            observers.remove(observer)
            return
        }
    }

    private func notifyObservers() {
        for observer in lock.withLock({ observers }) {
            observer.servicesManagerDidUpdate(services: services)
        }
    }

}

// MARK: - ServiceDelegate

extension ServicesManager: ServiceDelegate {

    func serviceUpdated(_ service: Service) {
        dispatchPrecondition(condition: .onQueue(queue))
        DispatchQueue.main.async {
            self.services = self.services
        }
    }

    func serviceDeleted(_ service: Service) {
        dispatchPrecondition(condition: .onQueue(queue))
        DispatchQueue.main.async {
            self.services.removeAll { type(of: $0) == type(of: service) }
        }
    }

}
