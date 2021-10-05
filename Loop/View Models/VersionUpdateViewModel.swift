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
        return versionUpdate != nil && versionUpdate != .noneNeeded
    }
    
    @ViewBuilder
    var icon: some View {
        switch versionUpdate {
        case .criticalNeeded:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.warning)
        default:
            EmptyView()
        }
    }
    
    lazy private var cancellables = Set<AnyCancellable>()

    weak var versionCheckServicesManager: VersionCheckServicesManager?
    
    init(_ versionCheckServicesManager: VersionCheckServicesManager? = nil) {
        self.versionCheckServicesManager = versionCheckServicesManager
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.performCheck()
            }
            .store(in: &cancellables)
        performCheck()
    }
    
    public func performCheck() {
        if #available(iOS 15.0.0, *) {
            Task {
                self.versionUpdate = versionCheckServicesManager?.checkVersion(currentVersion: Bundle.main.shortVersionString)
            }
        } else {
            self.versionUpdate = versionCheckServicesManager?.checkVersion(currentVersion: Bundle.main.shortVersionString)
        }
    }
    
    func gotoAppStore() {
        // TODO: use real App Store URL
        UIApplication.shared.open(URL(string: "itms-apps://itunes.apple.com/us/app/apple-store/id1474388545")!)
    }

}
