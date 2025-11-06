//
//  SpawnStatsView.swift
//  SpawnDeckFeature
//
//  Displays deck statistics including mode selection, cards remaining, and discard pile
//

import SwiftUI
import CoreDomain

public struct SpawnStatsView: View {
    @Binding var mode: SpawnDeckMode
    let cardsRemaining: Int
    let cardsDiscarded: Int
    let needsReshuffle: Bool
    let discardPileEmpty: Bool
    let showCheckmark: Bool
    let onModeChange: (SpawnDeckMode, SpawnDeckMode) -> Void
    let onDiscardPileTap: () -> Void

    public init(
        mode: Binding<SpawnDeckMode>,
        cardsRemaining: Int,
        cardsDiscarded: Int,
        needsReshuffle: Bool,
        discardPileEmpty: Bool,
        showCheckmark: Bool,
        onModeChange: @escaping (SpawnDeckMode, SpawnDeckMode) -> Void,
        onDiscardPileTap: @escaping () -> Void
    ) {
        self._mode = mode
        self.cardsRemaining = cardsRemaining
        self.cardsDiscarded = cardsDiscarded
        self.needsReshuffle = needsReshuffle
        self.discardPileEmpty = discardPileEmpty
        self.showCheckmark = showCheckmark
        self.onModeChange = onModeChange
        self.onDiscardPileTap = onDiscardPileTap
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Mode Toggle
            modeSwitcher

            // Deck Status
            deckStatusBar

            // Discard Pile - compact style matching deck status
            discardPileButton
        }
    }

    // MARK: - Mode Switcher

    private var modeSwitcher: some View {
        Picker("Mode", selection: $mode) {
            ForEach(SpawnDeckMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { oldValue, newValue in
            onModeChange(oldValue, newValue)
        }
    }

    // MARK: - Deck Status Bar

    private var deckStatusBar: some View {
        HStack {
            Label("\(cardsRemaining) cards remaining", systemImage: "rectangle.stack")
                .font(.headline)

            Spacer()

            if needsReshuffle {
                Label("Reshuffle needed", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Discard Pile Button

    private var discardPileButton: some View {
        Button {
            onDiscardPileTap()
        } label: {
            HStack {
                Image(systemName: showCheckmark ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .contentTransition(.symbolEffect(.replace.downUp.byLayer))

                Text("\(cardsDiscarded) cards discarded")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                // Tap hint when cards are available
                if !discardPileEmpty {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(discardPileEmpty)
        .opacity(discardPileEmpty ? 0.5 : 1.0)
        .padding(.top, -5)
    }
}

#Preview {
    SpawnStatsView(
        mode: .constant(.hard),
        cardsRemaining: 35,
        cardsDiscarded: 5,
        needsReshuffle: false,
        discardPileEmpty: false,
        showCheckmark: false,
        onModeChange: { _, _ in },
        onDiscardPileTap: {}
    )
    .padding()
}
