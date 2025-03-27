//
//  Publisher.swift
//  Loop
//
//  Created by Pete Schwamb on 3/20/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Combine
import Foundation
import Observation

public func withObservationTracking<T: Sendable>(of value: @escaping @autoclosure () -> T, execute: @escaping (T) -> Void) {
    Observation.withObservationTracking {
        execute(value())
    } onChange: {
        RunLoop.current.perform {
            withObservationTracking(of: value(), execute: execute)
        }
    }
}


enum ObservablePublishers {
    static func tracking<Object: Observable, Value>(
        _ object: Object,
        keyPath: KeyPath<Object, Value>
    ) -> AnyPublisher<Value, Never> {
        let subject = PassthroughSubject<Value, Never>()
        
        withObservationTracking(of: object[keyPath: keyPath]) { newValue in
            // When change happens, continue the loop
            Task { @MainActor in
                subject.send(newValue)
            }
        }
        
        subject.send(object[keyPath: keyPath])

        return subject.eraseToAnyPublisher()
    }
}
