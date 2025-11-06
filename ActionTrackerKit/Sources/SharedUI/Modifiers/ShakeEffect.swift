//
//  ShakeEffect.swift
//  SharedUI
//
//  View modifier that creates a smooth horizontal shake animation.
//  Used to indicate deletable action tokens in edit mode.
//

import SwiftUI

/// View modifier that creates a smooth horizontal shake animation
/// Used to indicate deletable action tokens in edit mode
public struct ShakeEffect: ViewModifier {
    let isShaking: Bool
    @State private var offset: CGFloat = 0

    public init(isShaking: Bool) {
        self.isShaking = isShaking
    }

    public func body(content: Content) -> some View {
        content
            .offset(x: offset)
            // Apply repeating animation when shaking, default animation when stopping
            .animation(isShaking ? .easeInOut(duration: 0.1).repeatForever(autoreverses: true) : .default, value: offset)
            .onChange(of: isShaking) { oldValue, newValue in
                if newValue {
                    // Start shaking
                    offset = 2
                } else {
                    // Stop shaking
                    offset = 0
                }
            }
            .onAppear {
                if isShaking {
                    offset = 2
                }
            }
    }
}

// MARK: - View Extension

public extension View {
    /// Applies a shake effect to the view
    /// - Parameter isShaking: Whether the view should shake
    /// - Returns: Modified view with shake animation
    func shake(isShaking: Bool) -> some View {
        modifier(ShakeEffect(isShaking: isShaking))
    }
}
