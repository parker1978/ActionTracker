//
//  DeckSummaryHeader.swift
//  SharedUI
//
//  Phase 4: Shared UI components for weapon deck display
//

import SwiftUI

/// Displays summary information for a weapon deck
/// Shows remaining cards, discard count, and deck type indicator
public struct DeckSummaryHeader: View {
    public let deckTypeName: String
    public let deckColor: Color
    public let remainingCount: Int
    public let discardCount: Int
    public var onTapRemaining: (() -> Void)?
    public var onTapDiscard: (() -> Void)?

    public init(
        deckTypeName: String,
        deckColor: Color,
        remainingCount: Int,
        discardCount: Int,
        onTapRemaining: (() -> Void)? = nil,
        onTapDiscard: (() -> Void)? = nil
    ) {
        self.deckTypeName = deckTypeName
        self.deckColor = deckColor
        self.remainingCount = remainingCount
        self.discardCount = discardCount
        self.onTapRemaining = onTapRemaining
        self.onTapDiscard = onTapDiscard
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(deckTypeName + " Deck")
                    .font(.headline)

                HStack(spacing: 12) {
                    if let onTapRemaining = onTapRemaining {
                        Button(action: onTapRemaining) {
                            statsLabel(
                                count: remainingCount,
                                label: "cards",
                                icon: "rectangle.stack",
                                color: .secondary
                            )
                        }
                    } else {
                        statsLabel(
                            count: remainingCount,
                            label: "cards",
                            icon: "rectangle.stack",
                            color: .secondary
                        )
                    }

                    if let onTapDiscard = onTapDiscard {
                        Button(action: onTapDiscard) {
                            statsLabel(
                                count: discardCount,
                                label: "discard",
                                icon: "tray",
                                color: discardCount > 0 ? .orange : .secondary
                            )
                        }
                    } else {
                        statsLabel(
                            count: discardCount,
                            label: "discard",
                            icon: "tray",
                            color: discardCount > 0 ? .orange : .secondary
                        )
                    }
                }
            }

            Spacer()

            // Deck color indicator
            Circle()
                .fill(deckColor.gradient)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func statsLabel(count: Int, label: String, icon: String, color: Color) -> some View {
        Label("\(count) \(label)", systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(color)
    }
}

#Preview {
    VStack(spacing: 16) {
        DeckSummaryHeader(
            deckTypeName: "Regular",
            deckColor: .blue,
            remainingCount: 42,
            discardCount: 8,
            onTapRemaining: {},
            onTapDiscard: {}
        )

        DeckSummaryHeader(
            deckTypeName: "Starting",
            deckColor: .green,
            remainingCount: 12,
            discardCount: 0
        )

        DeckSummaryHeader(
            deckTypeName: "Ultrared",
            deckColor: .red,
            remainingCount: 5,
            discardCount: 23,
            onTapRemaining: {},
            onTapDiscard: {}
        )
    }
    .padding()
}
