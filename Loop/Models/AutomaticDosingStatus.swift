//
//  AutomaticDosingStatus.swift
//  Loop
//
//  Created by Nathaniel Hamming on 2021-05-28.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

@Observable
public class AutomaticDosingStatus {
    public var automaticDosingEnabled: Bool
    public var isAutomaticDosingAllowed: Bool

    public init(automaticDosingEnabled: Bool,
                isAutomaticDosingAllowed: Bool)
    {
        self.automaticDosingEnabled = automaticDosingEnabled
        self.isAutomaticDosingAllowed = isAutomaticDosingAllowed
    }
}
