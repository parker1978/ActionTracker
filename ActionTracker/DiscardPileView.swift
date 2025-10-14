//
//  DiscardPileView.swift
//  ZombiTrack
//
//  Full-screen view for browsing discarded spawn cards
//

import SwiftUI

struct DiscardPileView: View {
    @ObservedObject var deckManager: SpawnDeckManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero

    var body: some View {
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
                                cardView(card: card)
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

    // MARK: - Card View

    private func cardView(card: SpawnCard) -> some View {
        VStack(spacing: 0) {
            // Card Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.type.rawValue.uppercased())
                        .font(card.type == .extraActivation ? .title3 : .title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    if card.isRush {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                            Text("RUSH!")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.yellow.opacity(0.25), in: Capsule())
                    }
                }

                Spacer()

                Text("#\(card.id)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding()
            .background(card.type == .extraActivation ? Color.red : Color.black)
            .cornerRadius(16, corners: [.topLeft, .topRight])

            // Spawn Counts - round bottom corners only if there's no note
            VStack(spacing: 16) {
                difficultyRow(level: .blue, count: card.spawnCount(for: .blue), isExtraActivation: card.type == .extraActivation)
                difficultyRow(level: .yellow, count: card.spawnCount(for: .yellow), isExtraActivation: card.type == .extraActivation)
                difficultyRow(level: .orange, count: card.spawnCount(for: .orange), isExtraActivation: card.type == .extraActivation)
                difficultyRow(level: .red, count: card.spawnCount(for: .red), isExtraActivation: card.type == .extraActivation)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .if(card.note.isEmpty) { view in
                view.cornerRadius(16, corners: [.bottomLeft, .bottomRight])
            }

            // Note Section - only show if there's a note
            if !card.note.isEmpty {
                Text(card.note)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(card.isRush ? Color.yellow : Color.yellow.opacity(0.3))
                    .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
            }
        }
        .frame(maxWidth: .infinity, minHeight: 450, maxHeight: 450)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }

    private func difficultyRow(level: DifficultyLevel, count: String, isExtraActivation: Bool) -> some View {
        HStack(spacing: 12) {
            // Color indicator with icon
            ZStack {
                Circle()
                    .fill(colorForDifficulty(level))
                    .frame(width: 40, height: 40)

                Image(systemName: "figure.walk")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }

            Text(level.displayName)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(width: 80, alignment: .leading)

            Spacer()

            // Spawn count - smaller text for Extra Activation
            Text(count)
                .font(isExtraActivation ? .system(size: 20, weight: .bold, design: .rounded) : .system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(colorForDifficulty(level))
                .frame(minWidth: 60, alignment: .trailing)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func colorForDifficulty(_ level: DifficultyLevel) -> Color {
        switch level {
        case .blue: return .blue
        case .yellow: return .yellow
        case .orange: return .orange
        case .red: return .red
        }
    }
}

// Note: Extensions for cornerRadius and `if` are defined in SpawnDeckView.swift

#Preview {
    let manager = SpawnDeckManager()
    manager.loadDeck()
    manager.drawCard()
    manager.drawCard()
    manager.drawCard()
    return DiscardPileView(deckManager: manager)
}
