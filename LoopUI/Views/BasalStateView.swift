//
//  BasalStateView.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import SwiftUI
import LoopKitUI

class WrappedBasalRateViewModel: ObservableObject {
    
    private lazy var basalRateUnitString = LocalizedString("U/hr", comment: "The format string describing the basal rate unit.")
    private lazy var basalRateFormatString = "%1$d %2$@"
    
    @Published var basalDisplayState: BasalDisplayState
    @Published var tintColor: Color
    
    var basalStateImageName: String? {
        basalDisplayState.imageName
    }
    var manualTempBasalAmount: Double? {
        switch basalDisplayState {
        case .basalTempManual(let double):
             return double
        default:
            return nil
        }
    }
    var manualTempBasalAmountString: String? {
        guard let manualTempBasalAmount = manualTempBasalAmount else { return nil }
        return "\(manualTempBasalAmount)"
    }
    var basalStateCaptionString: String? {
        switch basalDisplayState {
        case .basalTempManual: return basalRateUnitString
        case .basalTempAutoNoDelivery: return String(format: basalRateFormatString, 0, basalRateUnitString)
        default: return nil
        }
    }
    var isBasalTempManual: Bool {
        switch basalDisplayState {
        case .basalTempManual: return true
        default: return false
        }
    }
        
    init(basalDisplayState: BasalDisplayState = .basalScheduled,
         tintColor: Color = .insulinTintColor
    ) {
        self.basalDisplayState = basalDisplayState
        self.tintColor = tintColor
    }
}

struct WrappedBasalRateView: View {
    
    @StateObject var viewModel: WrappedBasalRateViewModel
    
    var body: some View {
        VStack {
            if let basalStateImageName = viewModel.basalStateImageName {
                Image(systemName: basalStateImageName)
                    .font(.title)
                    .foregroundStyle(viewModel.tintColor)
            }
            if let manualTempBasalAmountString = viewModel.manualTempBasalAmountString {
                Text(manualTempBasalAmountString)
                    .font(.system(size: 24))
                    .fontWeight(.heavy)
                    .bold()
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(viewModel.tintColor)
            }
            if let basalStateCaptionString = viewModel.basalStateCaptionString {
                Text(basalStateCaptionString)
                    .font(.caption2)
                    .foregroundStyle(viewModel.isBasalTempManual ? .secondary : .primary)
            }
        }
        .animation(.default, value: viewModel.basalDisplayState)
    }
}

class BasalRateHostingController: UIHostingController<WrappedBasalRateView> {
    init(viewModel: WrappedBasalRateViewModel) {
        super.init(
            rootView: WrappedBasalRateView(
                viewModel: viewModel
            )
        )
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}


public final class BasalStateView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setupViews()
    }
    
    var basalDisplayState: BasalDisplayState = .basalScheduled {
        didSet {
            viewModel.basalDisplayState = basalDisplayState
        }
    }
    
    public override func tintColorDidChange() {
        super.tintColorDidChange()
        viewModel.tintColor = Color(uiColor: tintColor)
    }
    
    private let viewModel = WrappedBasalRateViewModel()
    
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
