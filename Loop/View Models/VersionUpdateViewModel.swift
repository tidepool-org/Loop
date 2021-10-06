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

public class VersionUpdateViewModel: ObservableObject {
    
    @Published var versionUpdate: VersionUpdate?

    var softwareUpdateAvailable: Bool {
        update()
        return versionUpdate != nil && versionUpdate != .noneNeeded
    }
    
    @ViewBuilder
    var icon: some View {
        switch versionUpdate {
        case .criticalNeeded, .supportedNeeded:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(warningColor)
        default:
            EmptyView()
        }
    }
    
    var warningColor: Color {
        switch versionUpdate {
        case .criticalNeeded: return .critical
        case .supportedNeeded: return .warning
        default: return .primary
        }
    }
    
    lazy private var cancellables = Set<AnyCancellable>()

    weak var versionCheckServicesManager: VersionCheckServicesManager?
    
    init(_ versionCheckServicesManager: VersionCheckServicesManager? = nil) {
        self.versionCheckServicesManager = versionCheckServicesManager
        
        NotificationCenter.default.publisher(for: .SoftwareUpdateAvailable)
            .sink { [weak self] _ in
                self?.update()
            }
            .store(in: &cancellables)
        
        update()
    }
    
    public func update() {
        versionCheckServicesManager?.checkVersion(currentVersion: Bundle.main.shortVersionString) {
            self.versionUpdate = $0
        }
    }
    
    func gotoAppStore() {
        // TODO: use real App Store URL
        UIApplication.shared.open(URL(string: "itms-apps://itunes.apple.com/us/app/apple-store/id1474388545")!)
    }

}
