//
//  SpawnDeckView.swift
//  ZombiTrack
//
//  Main view for the Spawn Deck feature
//  Displays cards, handles drawing, shuffling, and mode switching
//

import SwiftUI
import SharedUI

struct SpawnDeckView: View {
    @StateObject private var deckManager = SpawnDeckManager()
    @State private var showingDiscardPile = false
    @State private var dragOffset: CGSize = .zero
    @State private var isAnimatingDiscard = false
    @State private var showCheckmark = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Mode Toggle
                    modeSwitcher

                    // Deck Status
                    deckStatusBar
                    
                    // Discard Pile - compact style matching deck status
                    Button {
                        showingDiscardPile = true
                    } label: {
                        HStack {
                            Image(systemName: showCheckmark ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .contentTransition(.symbolEffect(.replace.downUp.byLayer))

                            Text("\(deckManager.cardsDiscarded) cards discarded")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            // Tap hint when cards are available
                            if !deckManager.discardPile.isEmpty {
                                Image(systemName: "hand.tap.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(deckManager.discardPile.isEmpty)
                    .opacity(deckManager.discardPile.isEmpty ? 0.5 : 1.0)
                    .padding(.top, -5)

                    // Swipe/Tap hint - tappable to discard
                    if deckManager.currentCard != nil {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isAnimatingDiscard = true
                                dragOffset = CGSize(width: -1000, height: 0)
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                deckManager.drawCard()
                                dragOffset = .zero
                                isAnimatingDiscard = false

                                // Trigger checkmark animation
                                showCheckmark = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    showCheckmark = false
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.left")
                                    .font(.title3)
                                Text("Swipe or Tap to Discard")
                                    .font(.headline)
                                Image(systemName: "arrow.right")
                                    .font(.title3)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.7), in: Capsule())
                            .shadow(radius: 4)
                        }
                        .disabled(isAnimatingDiscard)
                    }

                    // Main Card Display with Drag Gesture
                    ZStack {
                        if let card = deckManager.currentCard {
                            cardView(card: card)
                                .offset(x: dragOffset.width, y: dragOffset.height * 0.3)
                                .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                                .opacity(isAnimatingDiscard ? 0 : 1 - Double(abs(dragOffset.width) / 500))
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if !isAnimatingDiscard {
                                                dragOffset = value.translation
                                            }
                                        }
                                        .onEnded { value in
                                            let swipeThreshold: CGFloat = 200 // Increased from 150 for more deliberate swipe

                                            if abs(dragOffset.width) > swipeThreshold {
                                                // Swiped far enough - discard and draw next
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    isAnimatingDiscard = true
                                                    dragOffset = CGSize(
                                                        width: dragOffset.width > 0 ? 1000 : -1000,
                                                        height: dragOffset.height
                                                    )
                                                }

                                                // Draw next card after animation
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    deckManager.drawCard()
                                                    dragOffset = .zero
                                                    isAnimatingDiscard = false

                                                    // Trigger checkmark animation
                                                    showCheckmark = true
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                        showCheckmark = false
                                                    }
                                                }
                                            } else {
                                                // Snap back
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    dragOffset = .zero
                                                }
                                            }
                                        }
                                )
                        } else if deckManager.hasCardsRemaining {
                            // Show initial state placeholder when cards available but none drawn yet
                            initialStatePlaceholder
                        } else {
                            // Show empty placeholder when deck is fully exhausted
                            emptyCardPlaceholder
                        }
                    }
                    .frame(height: 500)
                }
                .padding()
            }
            .navigationTitle("Spawn Deck")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            // Return current card to draw pile if exists
                            if let currentCard = deckManager.currentCard {
                                deckManager.drawPile.append(currentCard)
                                deckManager.currentCard = nil
                            }
                            deckManager.shuffleDeck()
                            // Reset animation states
                            dragOffset = .zero
                            isAnimatingDiscard = false
                        }
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .disabled(!deckManager.hasCardsRemaining && deckManager.currentCard == nil)

                    Button {
                        withAnimation {
                            deckManager.resetDeck()
                            // Reset animation states
                            dragOffset = .zero
                            isAnimatingDiscard = false
                        }
                    } label: {
                        Label("Reset", systemImage: "arrow.clockwise")
                    }
                    .disabled(deckManager.discardPile.isEmpty && deckManager.currentCard == nil)
                }
            }
            .sheet(isPresented: $showingDiscardPile) {
                DiscardPileView(deckManager: deckManager)
                    .presentationDetents([.fraction(0.85), .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                if deckManager.drawPile.isEmpty && deckManager.currentCard == nil {
                    deckManager.loadDeck()
                }
            }
        }
    }

    // MARK: - Mode Switcher

    private var modeSwitcher: some View {
        Picker("Mode", selection: $deckManager.mode) {
            ForEach(SpawnDeckMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: deckManager.mode) { oldValue, newValue in
            deckManager.switchMode(to: newValue)
            // Reset any animation states
            dragOffset = .zero
            isAnimatingDiscard = false
        }
    }

    // MARK: - Deck Status Bar

    private var deckStatusBar: some View {
        HStack {
            Label("\(deckManager.cardsRemaining) cards remaining", systemImage: "rectangle.stack")
                .font(.headline)

            Spacer()

            if deckManager.needsReshuffle {
                Label("Reshuffle needed", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
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
                .foregroundStyle(level.color)
                .frame(minWidth: 60, alignment: .trailing)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty Card Placeholder

    private var emptyCardPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.fill.badge.minus")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("Deck Empty")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            Text("All cards have been drawn")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    deckManager.resetDeck()
                    // Reset animation states
                    dragOffset = .zero
                    isAnimatingDiscard = false
                }
            } label: {
                Label("Reset Deck", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 450)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Initial State Placeholder

    private var initialStatePlaceholder: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                _ = deckManager.drawCard()
            }
        } label: {
            VStack(spacing: 20) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("Tap to begin!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 450)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Statistic Card

    private func statisticCard(title: String, value: String, icon: String, color: Color, showTapHint: Bool = false) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(color)
                    .contentTransition(.symbolEffect(.replace.downUp.byLayer))

                // Show tap indicator for discard pile
                if showTapHint && value != "0" {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .offset(x: 8, y: -8)
                }
            }

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SpawnDeckView()
}
