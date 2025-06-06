//
//  BasalStateView.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI

class WrappedTreatmentArrowViewModel: ObservableObject {
    
    private lazy var basalRateUnitString = LocalizedString("U/hr", comment: "The format string describing the basal rate unit.")
    private lazy var basalRateFormatString = "%1$d %2$@"
    
    @Published var treatmentArrowState: AutomatedTreatmentState
    @Published var tintColor: Color
    
    var basalStateImageName: String? {
        treatmentArrowState.imageName
    }

    var basalStateCaptionString: String? {
        switch treatmentArrowState {
        case .minimumDelivery: return String(format: basalRateFormatString, 0, basalRateUnitString)
        default: return nil
        }
    }

    init(basalDisplayState: AutomatedTreatmentState = .neutralNoOverride,
         tintColor: Color = .insulinTintColor
    ) {
        self.treatmentArrowState = basalDisplayState
        self.tintColor = tintColor
    }
}

struct WrappedTreatmentArrowView: View {
    
    @StateObject var viewModel: WrappedTreatmentArrowViewModel
    
    var body: some View {
        VStack {
            if let basalStateImageName = viewModel.basalStateImageName {
                Image(systemName: basalStateImageName)
                    .font(.title)
                    .foregroundStyle(viewModel.tintColor)
            }
            if let basalStateCaptionString = viewModel.basalStateCaptionString {
                Text(basalStateCaptionString)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
        }
        .animation(.default, value: viewModel.treatmentArrowState)
    }
}

class BasalRateHostingController: UIHostingController<WrappedTreatmentArrowView> {
    init(viewModel: WrappedTreatmentArrowViewModel) {
        super.init(
            rootView: WrappedTreatmentArrowView(
                viewModel: viewModel
            )
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}


public final class TreatmentArrowStateView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setupViews()
    }
    
    var automatedTreatmentState: AutomatedTreatmentState = .neutralNoOverride {
        didSet {
            viewModel.treatmentArrowState = automatedTreatmentState
        }
    }
    
    public override func tintColorDidChange() {
        super.tintColorDidChange()
        viewModel.tintColor = Color(uiColor: tintColor)
    }
    
    private let viewModel = WrappedTreatmentArrowViewModel()
    
    private func setupViews() {
        let hostingController = BasalRateHostingController(viewModel: viewModel)
        
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        
        addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
