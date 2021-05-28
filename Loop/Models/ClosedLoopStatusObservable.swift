//
//  ClosedLoopStatusObservable.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2021-05-28.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

public class ClosedLoopStatusObservable: ObservableObject {
    @Published public var isClosedLoop: Bool

    public init(isClosedLoop: Bool) {
        self.isClosedLoop = isClosedLoop
    }
}

typealias AutomaticDosingObservable = ClosedLoopStatusObservable
