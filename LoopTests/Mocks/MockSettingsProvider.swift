//
//  MockSettingsProvider.swift
//  LoopTests
//
//  Created by Pete Schwamb on 11/28/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
@testable import Loop

struct MockSettingsProvider: SettingsProvider {
    var settings: StoredSettings
}
