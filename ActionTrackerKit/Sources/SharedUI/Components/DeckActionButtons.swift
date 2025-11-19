//
//  DeckActionButtons.swift
//  SharedUI
//
//  Phase 4: Shared UI components for weapon deck actions
//

import SwiftUI

/// Displays action buttons for deck operations (draw, draw two, shuffle)
/// Supports optional flashlight mode for drawing two cards
public struct DeckActionButtons: View {
    public let deckColor: Color
    public let deckType: String  // For determining if flashlight is allowed
    public let isEmpty: Bool
    public var enableDrawTwo: Binding<Bool>?
    public let onDraw: () -> Void
    public let onDrawTwo: (() -> Void)?

    public init(
        deckColor: Color,
        deckType: String,
        isEmpty: Bool,
        enableDrawTwo: Binding<Bool>? = nil,
        onDraw: @escaping () -> Void,
        onDrawTwo: (() -> Void)? = nil
    ) {
        self.deckColor = deckColor
        self.deckType = deckType
        self.isEmpty = isEmpty
        self.enableDrawTwo = enableDrawTwo
        self.onDraw = onDraw
        self.onDrawTwo = onDrawTwo
    }

    private var showFlashlightToggle: Bool {
        deckType == "Regular" && enableDrawTwo != nil && onDrawTwo != nil
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Draw Buttons Row
            HStack(spacing: 12) {
                // Draw 1 Button
                Button(action: onDraw) {
                    Label("Draw Card", systemImage: "plus.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(deckColor.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isEmpty)

                // Draw 2 Button (appears when flashlight enabled and Regular deck)
                if showFlashlightToggle, let binding = enableDrawTwo, binding.wrappedValue, let drawTwo = onDrawTwo {
                    Button(action: drawTwo) {
                        Label("Draw 2", systemImage: "plus.rectangle.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(deckColor.opacity(0.7).gradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isEmpty)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: enableDrawTwo?.wrappedValue)

            // Flashlight Toggle (Regular deck only)
            if showFlashlightToggle, let binding = enableDrawTwo {
                HStack {
                    Toggle("Flashlight Mode", isOn: binding)
                        .font(.subheadline)
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        Text("Regular Deck with Flashlight")
            .font(.headline)

        DeckActionButtons(
            deckColor: .blue,
            deckType: "Regular",
            isEmpty: false,
            enableDrawTwo: .constant(true),
            onDraw: {},
            onDrawTwo: {}
        )

        Text("Starting Deck (No Flashlight)")
            .font(.headline)

        DeckActionButtons(
            deckColor: .green,
            deckType: "Starting",
            isEmpty: false,
            onDraw: {}
        )

        Text("Empty Deck")
            .font(.headline)

        DeckActionButtons(
            deckColor: .red,
            deckType: "Ultrared",
            isEmpty: true,
            onDraw: {}
        )
    }
    .padding()
}
