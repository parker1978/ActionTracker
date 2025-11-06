//
//  DiscardPileView.swift
//  SpawnDeckFeature
//
//  Full-screen view for browsing discarded spawn cards
//

import SwiftUI
import CoreDomain
import SharedUI

public struct DiscardPileView: View {
    @ObservedObject var deckManager: SpawnDeckManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0

    public init(deckManager: SpawnDeckManager) {
        self.deckManager = deckManager
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.opacity(0.1)
                    .ignoresSafeArea()

                if deckManager.discardPile.isEmpty {
                    emptyDiscardView
                } else {
                    VStack(spacing: 20) {
                        // Card position indicator - count down from total
                        Text("Card \(deckManager.discardPile.count - currentIndex) of \(deckManager.discardPile.count)")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        // Card browser with swipe navigation
                        TabView(selection: $currentIndex) {
                            ForEach(Array(deckManager.discardPile.enumerated().reversed()), id: \.element.id) { index, card in
                                let cardIndex = deckManager.discardPile.count - 1 - index
                                SpawnCardView(card: card)
                                    .tag(cardIndex)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .indexViewStyle(.page(backgroundDisplayMode: .never))
                        .frame(maxHeight: 500)

                        // Navigation hints
                        HStack(spacing: 40) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundStyle(currentIndex < deckManager.discardPile.count - 1 ? .blue : .gray)

                            Text("Swipe to browse")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundStyle(currentIndex > 0 ? .blue : .gray)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Discard Pile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Start at the most recently discarded card (last in array, first to show)
                currentIndex = 0
            }
        }
    }

    // MARK: - Empty Discard View

    private var emptyDiscardView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("No Cards Discarded")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("Discarded cards will appear here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    let manager = SpawnDeckManager()
    manager.loadDeck()
    manager.drawCard()
    manager.drawCard()
    manager.drawCard()
    return DiscardPileView(deckManager: manager)
}
