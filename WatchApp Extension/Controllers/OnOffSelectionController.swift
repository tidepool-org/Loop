//
//  OnOffSelectionController.swift
//  WatchApp Extension
//
//  Created by Anna Quinlan on 8/20/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopCore


final class OnOffSelectionController: WKHostingController<OnOffSelectionView>, IdentifiableClass {
    
    private var viewModel: OnOffSelectionViewModel = OnOffSelectionViewModel(title: "", message: "", onSelection: {_ in })
    
    override func awake(withContext context: Any?) {
        if let model = context as? OnOffSelectionViewModel {
            model.dismiss = { self.dismiss() }
            self.viewModel = model
        }
    }

    override var body: OnOffSelectionView {
        OnOffSelectionView(viewModel: viewModel)
    }
}
