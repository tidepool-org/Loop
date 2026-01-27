//
//  LoopStateView.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/7/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import LoopKit
import LoopKitUI
import SwiftUI
import UIKit

class WrappedLoopStateViewModel: ObservableObject {
    @Published var loopStatusColors: StateColorPalette
    @Published var closedLoop: Bool
    @Published var freshness: LoopCompletionFreshness
    @Published var deviceInoperable: Bool
    
    init(
        loopStatusColors: StateColorPalette = StateColorPalette(unknown: .black, normal: .black, warning: .black, error: .black),
        closedLoop: Bool = true,
        freshness: LoopCompletionFreshness = .stale,
        deviceInoperable: Bool = false
    ) {
        self.loopStatusColors = loopStatusColors
        self.closedLoop = closedLoop
        self.freshness = freshness
        self.deviceInoperable = deviceInoperable
    }
}

struct WrappedLoopCircleView: View {
    
    @StateObject var viewModel: WrappedLoopStateViewModel
    
    var body: some View {
        LoopCircleView(animationAllowed: true, closedLoop: viewModel.closedLoop, freshness: viewModel.freshness, deviceInoperable: viewModel.deviceInoperable)
            .environment(\.loopStatusColorPalette, viewModel.loopStatusColors)
    }
}

class LoopCircleHostingController: UIHostingController<WrappedLoopCircleView> {
    init(viewModel: WrappedLoopStateViewModel) {
        super.init(
            rootView: WrappedLoopCircleView(
                viewModel: viewModel
            )
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}


final class LoopStateView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setupViews()
    }
    
    var loopStatusColors: StateColorPalette = StateColorPalette(unknown: .black, normal: .black, warning: .black, error: .black) {
        didSet {
            viewModel.loopStatusColors = loopStatusColors
        }
    }

    var freshness: LoopCompletionFreshness = .stale {
        didSet {
            viewModel.freshness = freshness
        }
    }
    
    var open = false {
        didSet {
            viewModel.closedLoop = !open
        }
    }
    
    var deviceInoperable: Bool = false {
        didSet {
            viewModel.deviceInoperable = deviceInoperable
        }
    }
    
    private let viewModel = WrappedLoopStateViewModel()
    
    private func setupViews() {
        let hostingController = LoopCircleHostingController(viewModel: viewModel)
        
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

