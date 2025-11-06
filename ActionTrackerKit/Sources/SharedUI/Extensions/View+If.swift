//
//  View+If.swift
//  SharedUI
//
//  Conditional view transformation utility.
//  Allows applying modifiers conditionally in a clean, chainable way.
//

import SwiftUI

public extension View {
    /// Conditionally applies a transformation to a view
    /// - Parameters:
    ///   - condition: Whether to apply the transformation
    ///   - transform: The transformation to apply if condition is true
    /// - Returns: Either the transformed view or the original view
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
