//
//  Image+Crop.swift
//  Loop
//
//  Created by Cameron Ingham on 3/20/25.
//

import AVKit
import SwiftUI

extension Image {
    func centerCropped() -> some View {
        GeometryReader { geo in
            self
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
    }
}

extension View {
    func centerCropped() -> some View {
        GeometryReader { geo in
            self
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
