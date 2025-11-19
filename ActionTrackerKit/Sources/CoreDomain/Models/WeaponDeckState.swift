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
    /// Applies multiple constraints:
    /// - Prevents back-to-back same-name weapons
    /// - Never starts deck with Bonus or Zombie cards
    /// - Keeps Zombie cards out of first 5 positions
    /// - Prevents adjacent Zombie cards (hard constraint)
    /// - Distributes Bonus cards evenly across deck
    /// - Minimizes adjacent Bonus cards (best effort)
    public func shuffle() {
        // Need at least 2 cards to apply constraints
        guard remaining.count > 1 else {
            remaining.shuffle()
            return
        }

        // Initial shuffle
        remaining.shuffle()

        // Priority 1: Fix position constraints
        fixStartingPositionConstraints()

        // Priority 2: Fix same-name adjacency (existing rule)
        fixAdjacentSameNameWeapons()

        // Priority 3: Fix zombie adjacency (hard constraint)
        fixAdjacentZombieCards()

        // Priority 4: Distribute bonus cards evenly
        distributeBonusCardsEvenly()

        // Priority 5: Minimize bonus adjacency (best effort)
        minimizeAdjacentBonusCards()
    }

    // MARK: - Shuffle Helper Methods

    /// Ensures no Bonus or Zombie cards at position 0, and Zombie cards not in first 5 positions
    private func fixStartingPositionConstraints() {
        guard remaining.count > 0 else { return }

        // Fix position 0 - must not be Bonus or Zombie
        if remaining[0].isBonus || remaining[0].isZombieCard {
            // Find first card that's neither Bonus nor Zombie
            if let swapIndex = remaining.firstIndex(where: { !$0.isBonus && !$0.isZombieCard }) {
                remaining.swapAt(0, swapIndex)
            }
        }

        // Move any Zombie cards from positions 0-4 to position 5 or later
        let minZombiePosition = 5
        if remaining.count > minZombiePosition {
            for i in 0..<min(minZombiePosition, remaining.count) {
                if remaining[i].isZombieCard {
                    // Find a non-zombie card at position 5 or later to swap with
                    if let swapIndex = remaining[minZombiePosition...].firstIndex(where: { !$0.isZombieCard }) {
                        remaining.swapAt(i, swapIndex)
                    }
                }
            }
        }
    }

    /// Prevents back-to-back weapons with the same name
    private func fixAdjacentSameNameWeapons() {
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

    /// Prevents adjacent Zombie cards (hard constraint)
    private func fixAdjacentZombieCards() {
        var i = 0
        while i < remaining.count - 1 {
            if remaining[i].isZombieCard && remaining[i + 1].isZombieCard {
                // Find next non-zombie card
                var swapIndex = i + 2
                while swapIndex < remaining.count && remaining[swapIndex].isZombieCard {
                    swapIndex += 1
                }

                if swapIndex < remaining.count {
                    // Found a non-zombie card, swap it with position i+1
                    remaining.swapAt(i + 1, swapIndex)
                    // Don't increment i - recheck this position
                } else if i > 0 && !remaining[0].isZombieCard {
                    // All remaining cards are zombies, wrap to start if position 0 is not zombie
                    remaining.swapAt(i + 1, 0)
                    // Don't increment i - recheck this position
                } else {
                    // Can't fix this (all cards are zombies), move on
                    i += 1
                }
            } else {
                i += 1
            }
        }
    }

    /// Distributes Bonus cards evenly across the deck
    private func distributeBonusCardsEvenly() {
        let bonusIndices = remaining.indices.filter { remaining[$0].isBonus }
        guard bonusIndices.count > 1 else { return }

        let deckSize = remaining.count
        let bonusCount = bonusIndices.count
        let spacing = Double(deckSize) / Double(bonusCount)

        // Calculate ideal positions for bonus cards
        var targetPositions: [Int] = []
        for i in 0..<bonusCount {
            let idealPosition = Int(spacing * Double(i) + spacing / 2)
            targetPositions.append(min(idealPosition, deckSize - 1))
        }

        // Move bonus cards to target positions
        var bonusCards = bonusIndices.map { remaining[$0] }

        // Remove bonus cards from current positions (in reverse to maintain indices)
        for index in bonusIndices.reversed() {
            remaining.remove(at: index)
        }

        // Insert bonus cards at target positions
        for (bonusCard, targetPos) in zip(bonusCards, targetPositions) {
            let insertPos = min(targetPos, remaining.count)
            remaining.insert(bonusCard, at: insertPos)
        }
    }

    /// Best-effort attempt to minimize adjacent Bonus cards
    private func minimizeAdjacentBonusCards() {
        var i = 0
        var attempts = 0
        let maxAttempts = remaining.count // Prevent infinite loops

        while i < remaining.count - 1 && attempts < maxAttempts {
            if remaining[i].isBonus && remaining[i + 1].isBonus {
                // Try to find a non-bonus card nearby to swap with position i+1
                var swapIndex = i + 2
                var foundSwap = false

                // Look ahead for a non-bonus card (within reasonable distance)
                while swapIndex < min(i + 10, remaining.count) {
                    if !remaining[swapIndex].isBonus {
                        remaining.swapAt(i + 1, swapIndex)
                        foundSwap = true
                        break
                    }
                    swapIndex += 1
                }

                if !foundSwap {
                    // Couldn't find a nearby swap, just move on
                    i += 1
                }
                attempts += 1
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

    /// Remove a card from remaining deck (e.g., when adding to inventory)
    public func removeFromRemaining(_ card: Weapon) {
        if let index = remaining.firstIndex(where: { $0.id == card.id || ($0.name == card.name && $0.expansion == card.expansion) }) {
            remaining.remove(at: index)
        }
    }

    // MARK: - Deck Reordering

    /// Move a card from remaining deck to the top
    public func moveCardToTop(_ card: Weapon) {
        if let index = remaining.firstIndex(where: { $0.id == card.id }) {
            remaining.remove(at: index)
            remaining.insert(card, at: 0)
        }
    }

    /// Move a card from remaining deck to the bottom
    public func moveCardToBottom(_ card: Weapon) {
        if let index = remaining.firstIndex(where: { $0.id == card.id }) {
            remaining.remove(at: index)
            remaining.append(card)
        }
    }

    /// Move a card from remaining deck to discard pile
    public func discardFromDeck(_ card: Weapon) {
        if let index = remaining.firstIndex(where: { $0.id == card.id }) {
            remaining.remove(at: index)
            discard.insert(card, at: 0)
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
