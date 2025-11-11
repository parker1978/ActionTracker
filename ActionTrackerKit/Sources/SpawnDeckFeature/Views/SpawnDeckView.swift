//
//  SpawnDeckView.swift
//  SpawnDeckFeature
//
//  Main view for the Spawn Deck feature
//  Coordinates card display, stats, gestures, and navigation
//

import SwiftUI
import CoreDomain
import SharedUI

public struct SpawnDeckView: View {
    @ObservedObject var deckManager: SpawnDeckManager
    @State private var showingDiscardPile = false
    @State private var dragOffset: CGSize = .zero
    @State private var isAnimatingDiscard = false
    @State private var showCheckmark = false
    @State private var shouldAutoScrollToFirstCard = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(deckManager: SpawnDeckManager) {
        self.deckManager = deckManager
    }

    public var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        // Stats Section
                        SpawnStatsView(
                            mode: $deckManager.mode,
                            cardsRemaining: deckManager.cardsRemaining,
                            cardsDiscarded: deckManager.cardsDiscarded,
                            needsReshuffle: deckManager.needsReshuffle,
                            discardPileEmpty: deckManager.discardPile.isEmpty,
                            showCheckmark: showCheckmark,
                            onModeChange: { oldValue, newValue in
                                deckManager.switchMode(to: newValue)
                                // Reset any animation states
                                dragOffset = .zero
                                isAnimatingDiscard = false
                                shouldAutoScrollToFirstCard = false
                            },
                            onDiscardPileTap: {
                                showingDiscardPile = true
                            }
                        )

                        // Swipe/Tap hint - tappable to discard
                        if deckManager.currentCard != nil {
                            discardHint
                        }

                        // Main Card Display with Drag Gesture
                        cardDisplayArea

                        // Scroll anchor for auto-scroll feature
                        Color.clear
                            .frame(height: 0)
                            .id("cardBottom")
                            .padding(.bottom, 16)
                    }
                    .padding()
                }
                .onChange(of: shouldAutoScrollToFirstCard) { _, shouldScroll in
                    guard shouldScroll else { return }

                    // Wait for card animation to complete before scrolling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if reduceMotion {
                            proxy.scrollTo("cardBottom", anchor: .bottom)
                        } else {
                            withAnimation(.easeOut(duration: 0.4)) {
                                proxy.scrollTo("cardBottom", anchor: .bottom)
                            }
                        }
                        shouldAutoScrollToFirstCard = false
                    }
                }
            }
            .navigationTitle("Spawn Deck")
            .toolbar {
                toolbarContent
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
            .onChange(of: deckManager.currentCard) { oldValue, newValue in
                // Trigger auto-scroll when first card is drawn in a new deck cycle
                if oldValue == nil && newValue != nil && deckManager.discardPile.isEmpty {
                    shouldAutoScrollToFirstCard = true
                }
            }
        }
    }

    // MARK: - Discard Hint

    private var discardHint: some View {
        Button {
            performDiscard()
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

    // MARK: - Card Display Area

    private var cardDisplayArea: some View {
        ZStack {
            if let card = deckManager.currentCard {
                SpawnCardView(card: card)
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
                                handleSwipeEnd()
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

    // MARK: - Placeholders

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
                    shouldAutoScrollToFirstCard = false
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
                    shouldAutoScrollToFirstCard = false
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
                    shouldAutoScrollToFirstCard = false
                }
            } label: {
                Label("Reset", systemImage: "arrow.clockwise")
            }
            .disabled(deckManager.discardPile.isEmpty && deckManager.currentCard == nil)
        }
    }

    // MARK: - Gesture Handling

    private func performDiscard() {
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
    }

    private func handleSwipeEnd() {
        let swipeThreshold: CGFloat = 200

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
}

#Preview {
    SpawnDeckView(deckManager: SpawnDeckManager())
}
