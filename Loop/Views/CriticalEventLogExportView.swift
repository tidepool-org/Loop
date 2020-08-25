//
//  CriticalEventLogExportView.swift
//  Loop
//
//  Created by Darin Krauss on 7/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI

struct CriticalEventLogExportView: View {
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: CriticalEventLogExportViewModel

    var body: some View {
        Group {
            Spacer()
            if viewModel.url == nil {
                exportingView
            } else {
                exportedView
            }
            Spacer()
            Spacer()
        }
        .navigationBarTitle(Text("Critical Event Logs", comment: "Critical event log export title"), displayMode: .automatic)
        .onAppear { self.viewModel.export() }
        .onDisappear { self.viewModel.cancel() }
        .alert(isPresented: $viewModel.showingError) {
            errorAlert
        }
    }

    @ViewBuilder
    private var exportingView: some View {
        VStack {
            Text("Preparing Critical Event Logs", comment: "Preparing critical event log text")
                .bold()
            ProgressView(progress: CGFloat(viewModel.progress))
                .accentColor(Color.loopAccent)
                .padding()
            Text(viewModel.remainingDurationString ?? " ")  // Vertical alignment hack
        }
    }

    @ViewBuilder
    private var exportedView: some View {
        VStack {
            Image("Checkmark")
                .foregroundColor(Color.loopAccent)
                .padding()
            Text("Critical Event Log Ready", comment: "Critical event log ready text")
                .bold()
        }
        .sheet(isPresented: Binding.constant(true), onDismiss: {
            self.viewModel.cancel()
            self.dismiss()
        }) {
            ActivityViewController(activityItems: [CriticalEventLogExportActivityItemSource(url: self.viewModel.url!)], applicationActivities: nil)
        }
    }

    private var errorAlert: SwiftUI.Alert {
        Alert(title: Text("Error Exporting Logs", comment: "Critical event log export error alert title"),
              message: Text("Critical Event Logs were not able to be exported.", comment: "Critical event log export error alert message"),
              primaryButton: errorAlertPrimaryButton,
              secondaryButton: errorAlertSecondaryButton)
    }

    private var errorAlertPrimaryButton: SwiftUI.Alert.Button {
        .cancel() {
            self.dismiss()
        }
    }

    private var errorAlertSecondaryButton: SwiftUI.Alert.Button {
        .default(Text("Try Again", comment: "Critical event log export error alert try again button")) {
            self.viewModel.export()
        }
    }
}

fileprivate struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

public struct CriticalEventLogExportView_Previews: PreviewProvider {
    public static var previews: some View {
        let exportingViewModel = CriticalEventLogExportViewModel(exporterFactory: MockCriticalEventLogExporterFactory())
        exportingViewModel.progress = 0.5
        exportingViewModel.remainingDurationString = "About 3 minutes remaining"
        let exportedViewModel = CriticalEventLogExportViewModel(exporterFactory: MockCriticalEventLogExporterFactory())
        exportedViewModel.url = URL(string: "file:///mock.txt")!
        return Group {
            CriticalEventLogExportView(viewModel: exportingViewModel)
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("Exporting - iPhone SE 2 - Light")
            CriticalEventLogExportView(viewModel: exportingViewModel)
                .colorScheme(.dark)
                .previewDevice(PreviewDevice(rawValue: "iPhone XS Max"))
                .previewDisplayName("Exporting - iPhone XS Max - Dark")
            CriticalEventLogExportView(viewModel: exportedViewModel)
                .colorScheme(.light)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
                .previewDisplayName("Exported - iPhone SE 2 - Light")
        }
    }
}

class MockCriticalEventLogExporterFactory: CriticalEventLogExporterFactory {
    func createExporter(to url: URL) -> CriticalEventLogExporter { MockCriticalEventLogExporter() }
}

class MockCriticalEventLogExporter: CriticalEventLogExporter {
    weak var delegate: CriticalEventLogExporterDelegate?

    var isCancelled: Bool = false
    func cancel() { isCancelled = true }

    func export(now: Date) -> Error? { isCancelled ? CriticalEventLogError.cancelled : nil }
}
