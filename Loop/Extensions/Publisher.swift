//
//  Publisher.swift
//  Loop
//
//  Created by Pete Schwamb on 3/20/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Combine
import Observation

enum ObservablePublishers {
    static func tracking<Object: Observable, Value>(
        _ object: Object,
        keyPath: KeyPath<Object, Value>
    ) -> AnyPublisher<Value, Never> {
        let subject = PassthroughSubject<Value, Never>()

        Task {
            while true {
                // Get the value and track access
                let initialValue = withObservationTracking {
                    object[keyPath: keyPath]
                } onChange: {
                    // When change happens, continue the loop
                    Task { @MainActor in
                        subject.send(object[keyPath: keyPath])
                    }
                }

                // Send initial value
                subject.send(initialValue)

                // Wait until the next change
                try? await Task.sleep(for: .seconds(100))
            }
        }

        return subject.eraseToAnyPublisher()
    }
}
