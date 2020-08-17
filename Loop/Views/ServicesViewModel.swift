//
//  ServicesViewModel.swift
//  Loop
//
//  Created by Rick Pasetto on 8/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

public class ServicesViewModel: ObservableObject {
    
    @Published var showServices: Bool
    @Published var availableServices: [AvailableService]
    @Published var activeServices: [Service]
    
    init(showServices: Bool,
                availableServices: [AvailableService],
                activeServices: [Service]) {
        self.showServices = showServices
        self.activeServices = activeServices
        self.availableServices = availableServices
    }
    
}
