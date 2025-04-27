//
//  KeyboardToolbarHelper.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/27/25.
//

import SwiftUI

struct KeyboardToolbar: ViewModifier {
    var onInsertText: (String) -> Void
    var onDone: () -> Void
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                // +1 button on the left
                ToolbarItem(placement: .keyboard) {
                    Button("+1") {
                        onInsertText("+1 ")
                    }
                }
                
                // Colon button on the left center
                ToolbarItem(placement: .keyboard) {
                    Button(":") {
                        onInsertText(": ")
                    }
                }
                
                // Timestamp button in the center
                ToolbarItem(placement: .keyboard) {
                    Button("📅") {
                        onInsertText(formattedDateTime() + " ")
                    }
                }
                
                // Spacer to push Done button to the right
                ToolbarItem(placement: .keyboard) {
                    Spacer()
                }
                
                // Done button on the right
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
    }
    
    private func formattedDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}

extension View {
    func keyboardToolbar(onInsertText: @escaping (String) -> Void, onDone: @escaping () -> Void) -> some View {
        self.modifier(KeyboardToolbar(onInsertText: onInsertText, onDone: onDone))
    }
}