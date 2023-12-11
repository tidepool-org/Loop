//
//  MockUploadEventListener.swift
//  LoopTests
//
//  Created by Pete Schwamb on 11/30/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
@testable import Loop

struct MockUploadEventListener: UploadEventListener {
    func triggerUpload(for triggeringType: Loop.RemoteDataType) {
    }
}
