//
//  WeaponDeckState.swift
//  ActionTracker
//
//  Manages deck state for Starting, Regular, and Ultrared weapon decks
//  Handles shuffling, drawing, discarding, and difficulty modes
//

import Foundation
import SwiftUI
import CoreDomain

// MARK: - Deck State

/// Manages the state of a single weapon deck (Starting, Regular, or Ultrared)
@Observable
public class WeaponDeckState {
    public let deckType: DeckType

    public private(set) var remaining: [Weapon] = []
    public private(set) var discard: [Weapon] = []
    public private(set) var recentDraws: [Weapon] = [] // Last 3 drawn cards
    public private(set) var drawHistory: [Weapon] = [] // All drawn cards (most recent first)

    // Full weapon list from repository
    private var sourceWeapons: [Weapon]

    public init(deckType: DeckType, weapons: [Weapon]) {
        self.deckType = deckType
        self.sourceWeapons = weapons.filter { $0.deck == deckType }
        self.remaining = []

        reset()
    }

    // MARK: - Deck Management

    /// Reset deck to initial state
    public func reset() {
        remaining = buildDeck()
        shuffle()
        discard.removeAll()
        recentDraws.removeAll()
        drawHistory.removeAll()
    }

    /// Shuffle remaining cards in deck
    /// Prevents back-to-back duplicates by swapping cards intelligently
    public func shuffle() {
        // Need at least 2 cards to check for duplicates
        guard remaining.count > 1 else {
            remaining.shuffle()
            return
        }

        // Initial shuffle
        remaining.shuffle()

        // Fix duplicates in a single pass
        var i = 0
        while i < remaining.count - 1 {
            if remaining[i].name == remaining[i + 1].name {
                // Find next card that's DIFFERENT from current
                var swapIndex = i + 2
                while swapIndex < remaining.count &&
                      remaining[swapIndex].name == remaining[i].name {
                    swapIndex += 1
                }

                if swapIndex < remaining.count {
                    // Found a different card, swap it with position i+1
                    remaining.swapAt(i + 1, swapIndex)
                    // Don't increment i - recheck this position in case swap created new duplicate
                } else if i > 0 && remaining[0].name != remaining[i].name {
                    // All remaining cards are identical, wrap to start if position 0 is different
                    remaining.swapAt(i + 1, 0)
                    // Don't increment i - recheck this position
                } else {
                    // Can't fix this duplicate (all cards are the same), move on
                    i += 1
                }
            } else {
                i += 1
            }
        }
    }

    /// Update weapon list (for expansion filtering) and reset
    public func updateWeapons(_ weapons: [Weapon]) {
        // Filter to only weapons for this deck type
        sourceWeapons = weapons.filter { $0.deck == deckType }
        reset()
    }

    // MARK: - Drawing Cards

    /// Draw a single card from the deck
    /// Automatically reshuffles discard if deck is empty
    public func draw() -> Weapon? {
        if remaining.isEmpty {
            reshuffleDiscardIntoDeck()
        }

        guard !remaining.isEmpty else { return nil }

        let card = remaining.removeFirst()
        recordDraw(card)
        return card
    }

    /// Draw two cards (for Flashlight or Draw 2 abilities)
    public func drawTwo() -> [Weapon] {
        var cards: [Weapon] = []

        if let first = draw() {
            cards.append(first)
        }

        if let second = draw() {
            cards.append(second)
        }

        return cards
    }

    // MARK: - Discard Management

    /// Add a card to the discard pile
    public func discardCard(_ card: Weapon) {
        discard.insert(card, at: 0) // Newest first
    }

    /// Return a card from discard to top of deck
    public func returnFromDiscardToTop(_ card: Weapon) {
        if let index = discard.firstIndex(where: { $0.id == card.id }) {
            discard.remove(at: index)
            remaining.insert(card, at: 0)
        }
    }

    /// Return a card from discard to bottom of deck
    public func returnFromDiscardToBottom(_ card: Weapon) {
        if let index = discard.firstIndex(where: { $0.id == card.id }) {
            discard.remove(at: index)
            remaining.append(card)
        }
    }

    /// Remove a card from discard pile (e.g., when adding to inventory)
    public func removeFromDiscard(_ card: Weapon) {
        if let index = discard.firstIndex(where: { $0.id == card.id }) {
            discard.remove(at: index)
        }
    }

    /// Move all cards from discard back into deck and shuffle
    public func reclaimAllDiscardIntoDeck(shuffle: Bool = true) {
        remaining.append(contentsOf: discard)
        discard.removeAll()

        if shuffle {
            self.shuffle()
        }
    }

    /// Clear discard pile (for dev/testing)
    public func clearDiscard() {
        discard.removeAll()
    }

    // MARK: - Recent Draws

    private func recordDraw(_ card: Weapon) {
        drawHistory.insert(card, at: 0)
        recentDraws = Array(drawHistory.prefix(3))
    }

    // MARK: - Deck Building

    /// Build deck with standard composition
    private func buildDeck() -> [Weapon] {
        var deck: [Weapon] = []

        for weapon in sourceWeapons {
            for _ in 0..<weapon.count {
                deck.append(weapon.duplicate())
            }
        }

        return deck
    }

    /// Reshuffle discard pile back into deck
    private func reshuffleDiscardIntoDeck() {
        guard !discard.isEmpty else {
            // Emergency: rebuild deck if both empty
            remaining = buildDeck()
            shuffle()
            return
        }

        remaining = discard
        discard.removeAll()
        shuffle()
    }

    // MARK: - Computed Properties

    public var remainingCount: Int {
        remaining.count
    }

    public var discardCount: Int {
        discard.count
    }

    public var isEmpty: Bool {
        remaining.isEmpty
    }
}
