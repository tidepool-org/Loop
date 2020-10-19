//
//  WKInterfaceImage.swift
//  Loop
//
//  Created by Nathan Racklyeft on 5/29/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import WatchKit

enum LoopImage: String {
    case fresh_open
    case aging_open
    case stale_open
    case unknown_open
    case fresh_closed
    case aging_closed
    case stale_closed
    case unknown_closed

    var imageName: String {
        return "loop_\(rawValue)"
    }
}


extension WKInterfaceImage {
    func setLoopImage(_ loopImage: LoopImage) {
        setImageNamed(loopImage.imageName)
    }
}
