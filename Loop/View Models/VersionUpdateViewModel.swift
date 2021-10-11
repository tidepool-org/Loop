//
//  VersionUpdateViewModel.swift
//  Loop
//
//  Created by Rick Pasetto on 10/4/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Combine
import Foundation
import LoopKit
import SwiftUI
import LoopKitUI

public class VersionUpdateViewModel: ObservableObject {
    
    @Published var versionUpdate: VersionUpdate?

    var softwareUpdateAvailable: Bool {
        update()
        return versionUpdate?.softwareUpdateAvailable ?? false
    }
    
    @ViewBuilder
    var icon: some View {
        switch versionUpdate {
        case .required, .recommended:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(warningColor)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    var softwareUpdateView: some View {
        versionCheckServicesManager?.softwareUpdateView(guidanceColors: guidanceColors)
    }
    
    var warningColor: Color {
        switch versionUpdate {
        case .required: return guidanceColors.critical
        case .recommended: return guidanceColors.warning
        default: return .primary
        }
    }
    
    private weak var versionCheckServicesManager: VersionCheckServicesManager?
    private let guidanceColors: GuidanceColors

    lazy private var cancellables = Set<AnyCancellable>()

    init(versionCheckServicesManager: VersionCheckServicesManager? = nil, guidanceColors: GuidanceColors) {
        self.versionCheckServicesManager = versionCheckServicesManager
        self.guidanceColors = guidanceColors
        
        NotificationCenter.default.publisher(for: .SoftwareUpdateAvailable)
            .sink { [weak self] _ in
                self?.update()
            }
            .store(in: &cancellables)
        
        update()
    }
    
    public func update() {
        versionCheckServicesManager?.checkVersion {
            self.versionUpdate = $0
        }
    }
    
}
