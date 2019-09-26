//
//  ServicesManager.swift
//  Loop
//
//  Created by Darin Krauss on 5/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

protocol ServicesManagerObserver {

    /// The service manager update the list of available services.
    ///
    /// - Parameter services: The list of available services
    func servicesManagerDidUpdate(services: [Service])

}

class ServicesManager {

    private let queue = DispatchQueue(label: "com.loopkit.ServicesManagerQueue", qos: .utility)

    private let lock = UnfairLock()

    private var observers = WeakSet<ServicesManagerObserver>()

    var services: [Service] {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            setupServices()
            UserDefaults.appGroup?.services = services
            notifyObservers()
        }
    }

    init() {
        self.services = UserDefaults.appGroup?.services ?? []
        setupServices()
    }

    private func setupServices() {
        dispatchPrecondition(condition: .onQueue(.main))

        services.forEach { service in
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

    func notifyServiceCreated(_ service: Service) {
        dispatchPrecondition(condition: .onQueue(.main))

        services.append(service)
    }

    func notifyServiceUpdated(_ service: Service) {
        dispatchPrecondition(condition: .onQueue(.main))

        UserDefaults.appGroup?.services = services
    }

    func notifyServiceDeleted(_ service: Service) {
        dispatchPrecondition(condition: .onQueue(.main))

       services.removeAll { type(of: $0) == type(of: service) }
    }

}
