//
//  KeyboardObserver.swift
//  Loop
//
//  Created by Michael Pangburn on 7/18/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import UIKit


final class Keyboard: ObservableObject {
    static let shared = Keyboard()

    @Published var height: CGFloat = 0
    @Published var animationDuration: TimeInterval = 0.25

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self, let userInfo = notification.userInfo else {
                    return
                }

                self.animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25

                if let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    self.height = UIScreen.main.bounds.intersection(keyboardFrame).height
                } else {
                    self.height = 0
                }
            }
            .store(in: &cancellables)
    }
}

import SwiftUI


struct KeyboardAware: ViewModifier {
    @ObservedObject var keyboard = Keyboard.shared

    func body(content: Content) -> some View {
        content
            .animation(nil)
            .padding(.bottom, keyboard.height)
            .edgesIgnoringSafeArea(keyboard.height > 0 ? .bottom : [])
            .animation(.easeInOut(duration: keyboard.animationDuration))
    }
}

extension View {
    func keyboardAware() -> some View {
        modifier(KeyboardAware())
    }
}



struct DismissibleKeyboardTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var textColor: UIColor = .label
    var textAlignment: NSTextAlignment = .natural
    var keyboardType: UIKeyboardType = .default

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = font
        textField.textColor = textColor
        textField.textAlignment = textAlignment
        textField.keyboardType = keyboardType
        textField.inputAccessoryView = makeDoneToolbar(for: textField)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        return textField
    }

    private func makeDoneToolbar(for textField: UITextField) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: textField, action: #selector(UITextField.resignFirstResponder))
        toolbar.items = [flexibleSpace, doneButton]
        toolbar.sizeToFit()
        return toolbar
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        textField.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator {
        var parent: DismissibleKeyboardTextField

        init(_ parent: DismissibleKeyboardTextField) {
            self.parent = parent
        }

        @objc fileprivate func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}
