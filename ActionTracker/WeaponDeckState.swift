//
//  WeaponDeckState.swift
//  ActionTracker
//
//  Manages deck state for Starting, Regular, and Ultrared weapon decks
//  Handles shuffling, drawing, discarding, and difficulty modes
//

import Foundation
import SwiftUI

// MARK: - Deck State

/// Manages the state of a single weapon deck (Starting, Regular, or Ultrared)
@Observable
class WeaponDeckState {
    let deckType: DeckType
    var difficulty: DifficultyMode

    private(set) var remaining: [Weapon] = []
    private(set) var discard: [Weapon] = []
    private(set) var recentDraws: [Weapon] = [] // Last 3 drawn cards
    private(set) var drawHistory: [Weapon] = [] // All drawn cards (most recent first)

    // Full weapon list from repository
    private var sourceWeapons: [Weapon]

    init(deckType: DeckType, difficulty: DifficultyMode, weapons: [Weapon]) {
        self.deckType = deckType
        self.difficulty = difficulty
        self.sourceWeapons = weapons.filter { $0.deck == deckType }
        self.remaining = []

        reset()
    }

    // MARK: - Deck Management

    /// Reset deck to initial state with current difficulty
    func reset() {
        remaining = buildDeck(mode: difficulty)
        remaining.shuffle()
        discard.removeAll()
        recentDraws.removeAll()
        drawHistory.removeAll()
    }

    /// Shuffle remaining cards in deck
    /// For Regular and Ultrared decks, prevents back-to-back duplicates
    func shuffle() {
        // Starting deck is too small, just shuffle normally
        guard deckType != .starting && remaining.count > 1 else {
            remaining.shuffle()
            return
        }

        // For Regular and Ultrared decks, prevent back-to-back duplicates
        var attempts = 0
        let maxAttempts = 10

        repeat {
            remaining.shuffle()
            attempts += 1

            // Check if we have back-to-back duplicates
            var hasBackToBack = false
            for i in 0..<(remaining.count - 1) {
                if remaining[i].name == remaining[i + 1].name {
                    hasBackToBack = true
                    break
                }
            }

            // If no back-to-back duplicates, we're done
            if !hasBackToBack {
                break
            }

            // If we've tried too many times, give up and accept it
            if attempts >= maxAttempts {
                break
            }
        } while true
    }

    /// Change difficulty and reset deck
    func changeDifficulty(to mode: DifficultyMode) {
        difficulty = mode
        reset()
    }

    /// Update weapon list (for expansion filtering) and reset
    func updateWeapons(_ weapons: [Weapon]) {
        // Filter to only weapons for this deck type
        sourceWeapons = weapons.filter { $0.deck == deckType }
        reset()
    }

    // MARK: - Drawing Cards

    /// Draw a single card from the deck
    /// Automatically reshuffles discard if deck is empty
    func draw() -> Weapon? {
        if remaining.isEmpty {
            reshuffleDiscardIntoDeck()
        }

        guard !remaining.isEmpty else { return nil }

        let card = remaining.removeFirst()
        recordDraw(card)
        return card
    }

    /// Draw two cards (for Flashlight or Draw 2 abilities)
    func drawTwo() -> [Weapon] {
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
    func discardCard(_ card: Weapon) {
        discard.insert(card, at: 0) // Newest first
    }

    /// Return a card from discard to top of deck
    func returnFromDiscardToTop(_ card: Weapon) {
        if let index = discard.firstIndex(where: { $0.id == card.id }) {
            discard.remove(at: index)
            remaining.insert(card, at: 0)
        }
    }

    /// Return a card from discard to bottom of deck
    func returnFromDiscardToBottom(_ card: Weapon) {
        if let index = discard.firstIndex(where: { $0.id == card.id }) {
            discard.remove(at: index)
            remaining.append(card)
        }
    }

    /// Remove a card from discard pile (e.g., when adding to inventory)
    func removeFromDiscard(_ card: Weapon) {
        if let index = discard.firstIndex(where: { $0.id == card.id }) {
            discard.remove(at: index)
        }
    }

    /// Move all cards from discard back into deck and shuffle
    func reclaimAllDiscardIntoDeck(shuffle: Bool = true) {
        remaining.append(contentsOf: discard)
        discard.removeAll()

        if shuffle {
            self.shuffle()
        }
    }

    /// Clear discard pile (for dev/testing)
    func clearDiscard() {
        discard.removeAll()
    }

    // MARK: - Recent Draws

    private func recordDraw(_ card: Weapon) {
        drawHistory.insert(card, at: 0)
        recentDraws = Array(drawHistory.prefix(3))
    }

    // MARK: - Deck Building with Difficulty

    /// Build deck with difficulty weighting applied
    private func buildDeck(mode: DifficultyMode) -> [Weapon] {
        var deck: [Weapon] = []

        switch mode {
        case .easy:
            // Weight toward powerful weapons
            for weapon in sourceWeapons {
                let baseCount = weapon.count
                var effectiveCount = baseCount

                if let dice = weapon.dice, dice >= 4 {
                    effectiveCount += baseCount
                }
                if let damage = weapon.damage, damage >= 3 {
                    effectiveCount += baseCount
                }

                for _ in 0..<effectiveCount {
                    deck.append(weapon.duplicate())
                }
            }

        case .medium:
            // Standard deck composition
            for weapon in sourceWeapons {
                for _ in 0..<weapon.count {
                    deck.append(weapon.duplicate())
                }
            }

        case .hard:
            // Weight toward weaker weapons
            for weapon in sourceWeapons {
                let baseCount = weapon.count
                var effectiveCount = baseCount

                if let dice = weapon.dice, dice <= 2 {
                    effectiveCount += baseCount
                }
                if let damage = weapon.damage, damage <= 1 {
                    effectiveCount += baseCount
                }
                if let accuracy = weapon.accuracyNumeric, accuracy >= 5 {
                    effectiveCount += baseCount
                }

                for _ in 0..<effectiveCount {
                    deck.append(weapon.duplicate())
                }
            }
        }

        return deck
    }

    /// Reshuffle discard pile back into deck
    private func reshuffleDiscardIntoDeck() {
        guard !discard.isEmpty else {
            // Emergency: rebuild with current difficulty if both empty
            remaining = buildDeck(mode: difficulty)
            remaining.shuffle()
            return
        }

        remaining = discard
        discard.removeAll()
        remaining.shuffle()
    }

    // MARK: - Computed Properties

    var remainingCount: Int {
        remaining.count
    }

    var discardCount: Int {
        discard.count
    }

    var isEmpty: Bool {
        remaining.isEmpty
    }
}

// MARK: - Weapons Manager

/// Manages all three weapon decks and global settings
@Observable
class WeaponsManager {
    private(set) var startingDeck: WeaponDeckState
    private(set) var regularDeck: WeaponDeckState
    private(set) var ultraredDeck: WeaponDeckState

    var currentDifficulty: DifficultyMode {
        didSet {
            if currentDifficulty != oldValue {
                changeDifficultyForAllDecks(to: currentDifficulty)
            }
        }
    }

    init(weapons: [Weapon], difficulty: DifficultyMode = .medium) {
        self.currentDifficulty = difficulty
        self.startingDeck = WeaponDeckState(deckType: .starting, difficulty: difficulty, weapons: weapons)
        self.regularDeck = WeaponDeckState(deckType: .regular, difficulty: difficulty, weapons: weapons)
        self.ultraredDeck = WeaponDeckState(deckType: .ultrared, difficulty: difficulty, weapons: weapons)
    }

    /// Get deck state by type
    func getDeck(_ type: DeckType) -> WeaponDeckState {
        switch type {
        case .starting: return startingDeck
        case .regular: return regularDeck
        case .ultrared: return ultraredDeck
        }
    }

    /// Change difficulty for all decks (resets all decks)
    private func changeDifficultyForAllDecks(to mode: DifficultyMode) {
        startingDeck.changeDifficulty(to: mode)
        regularDeck.changeDifficulty(to: mode)
        ultraredDeck.changeDifficulty(to: mode)
    }

    /// Reset all decks
    func resetAllDecks() {
        startingDeck.reset()
        regularDeck.reset()
        ultraredDeck.reset()
    }

    /// Update weapons for all decks (for expansion filtering)
    func updateWeapons(_ weapons: [Weapon]) {
        startingDeck.updateWeapons(weapons)
        regularDeck.updateWeapons(weapons)
        ultraredDeck.updateWeapons(weapons)
    }
}
