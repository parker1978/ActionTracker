//
//  SpawnDeckModels.swift
//  ZombiTrack
//
//  This file contains models for the Spawn Deck feature:
//  - SpawnCard: Individual spawn cards with difficulty-based spawn counts
//  - SpawnDeckManager: Manages deck state, shuffling, drawing, and game modes
//

import Foundation
import SwiftUI

// MARK: - Spawn Card Model

/// Represents a single spawn card from the Zombicide deck
/// Cards contain spawn information across 4 difficulty levels
struct SpawnCard: Identifiable, Codable, Equatable {
    let id: String // Card number (e.g., "001")
    let type: SpawnCardType
    let isRush: Bool
    let blue: Int
    let yellow: Int
    let orange: Int
    let red: Int
    let note: String

    /// Types of spawn cards in the deck
    enum SpawnCardType: String, Codable, CaseIterable {
        case walkers = "Walkers"
        case brutes = "Brutes"
        case runners = "Runners"
        case abomination = "Abomination"
        case extraActivation = "Extra Activation"
    }

    /// Get spawn count for a specific difficulty level
    func spawnCount(for difficulty: DifficultyLevel) -> String {
        switch difficulty {
        case .blue:
            // Special handling for Extra Activation cards
            if type == .extraActivation && blue == 0 {
                return "No One"
            }
            return blue == 0 ? "0" : "\(blue)"
        case .yellow:
            if type == .extraActivation {
                return note.isEmpty ? "All \(type.rawValue)" : note
            }
            return "\(yellow)"
        case .orange:
            if type == .extraActivation {
                return note.isEmpty ? "All \(type.rawValue)" : note
            }
            return "\(orange)"
        case .red:
            if type == .extraActivation {
                return note.isEmpty ? "All \(type.rawValue)" : note
            }
            return "\(red)"
        }
    }
}

// MARK: - Difficulty Level Enum

/// Four difficulty levels matching the game's color system
enum DifficultyLevel: String, Codable, CaseIterable {
    case blue = "Blue"
    case yellow = "Yellow"
    case orange = "Orange"
    case red = "Red"

    var displayName: String { rawValue }
}

// MARK: - Game Mode Enum

/// Easy mode uses cards 001-018, Hard mode uses all 40 cards
enum SpawnDeckMode: String, Codable, CaseIterable {
    case easy = "Easy"
    case hard = "Hard"

    var displayName: String { rawValue }

    /// Card range for this mode
    var cardRange: ClosedRange<Int> {
        switch self {
        case .easy: return 1...18
        case .hard: return 1...40
        }
    }
}

// MARK: - Hardcoded Deck Data

extension SpawnCard {
    /// The complete 40-card spawn deck, hardcoded for immediate availability
    static let fullDeck: [SpawnCard] = [
        // Walkers 001-008
        SpawnCard(id: "001", type: .walkers, isRush: false, blue: 1, yellow: 2, orange: 4, red: 6, note: ""),
        SpawnCard(id: "002", type: .walkers, isRush: false, blue: 2, yellow: 3, orange: 5, red: 7, note: ""),
        SpawnCard(id: "003", type: .walkers, isRush: false, blue: 3, yellow: 5, orange: 7, red: 9, note: ""),
        SpawnCard(id: "004", type: .walkers, isRush: false, blue: 4, yellow: 6, orange: 8, red: 10, note: ""),
        SpawnCard(id: "005", type: .walkers, isRush: true, blue: 1, yellow: 2, orange: 4, red: 6, note: "Spawn, then Activate."),
        SpawnCard(id: "006", type: .walkers, isRush: true, blue: 2, yellow: 3, orange: 5, red: 7, note: "Spawn, then Activate."),
        SpawnCard(id: "007", type: .walkers, isRush: true, blue: 3, yellow: 5, orange: 7, red: 9, note: "Spawn, then Activate."),
        SpawnCard(id: "008", type: .walkers, isRush: true, blue: 4, yellow: 6, orange: 8, red: 10, note: "Spawn, then Activate."),

        // Brutes 009-012
        SpawnCard(id: "009", type: .brutes, isRush: false, blue: 1, yellow: 1, orange: 2, red: 3, note: ""),
        SpawnCard(id: "010", type: .brutes, isRush: false, blue: 2, yellow: 3, orange: 4, red: 4, note: ""),
        SpawnCard(id: "011", type: .brutes, isRush: true, blue: 0, yellow: 1, orange: 2, red: 3, note: "Spawn, then Activate."),
        SpawnCard(id: "012", type: .brutes, isRush: true, blue: 1, yellow: 2, orange: 3, red: 4, note: "Spawn, then Activate."),

        // Runners 013-016
        SpawnCard(id: "013", type: .runners, isRush: false, blue: 0, yellow: 1, orange: 2, red: 3, note: ""),
        SpawnCard(id: "014", type: .runners, isRush: false, blue: 1, yellow: 1, orange: 2, red: 3, note: ""),
        SpawnCard(id: "015", type: .runners, isRush: false, blue: 1, yellow: 2, orange: 3, red: 4, note: ""),
        SpawnCard(id: "016", type: .runners, isRush: false, blue: 2, yellow: 3, orange: 4, red: 4, note: ""),

        // Abominations 017-018
        SpawnCard(id: "017", type: .abomination, isRush: false, blue: 0, yellow: 1, orange: 1, red: 1, note: ""),
        SpawnCard(id: "018", type: .abomination, isRush: false, blue: 0, yellow: 1, orange: 1, red: 1, note: ""),

        // Walkers 019-026
        SpawnCard(id: "019", type: .walkers, isRush: false, blue: 2, yellow: 4, orange: 6, red: 8, note: ""),
        SpawnCard(id: "020", type: .walkers, isRush: false, blue: 3, yellow: 5, orange: 7, red: 9, note: ""),
        SpawnCard(id: "021", type: .walkers, isRush: false, blue: 4, yellow: 6, orange: 8, red: 10, note: ""),
        SpawnCard(id: "022", type: .walkers, isRush: false, blue: 6, yellow: 8, orange: 10, red: 12, note: ""),
        SpawnCard(id: "023", type: .walkers, isRush: true, blue: 2, yellow: 4, orange: 6, red: 8, note: "Spawn, then Activate."),
        SpawnCard(id: "024", type: .walkers, isRush: true, blue: 3, yellow: 5, orange: 7, red: 9, note: "Spawn, then Activate."),
        SpawnCard(id: "025", type: .walkers, isRush: true, blue: 4, yellow: 6, orange: 8, red: 10, note: "Spawn, then Activate."),
        SpawnCard(id: "026", type: .walkers, isRush: true, blue: 6, yellow: 8, orange: 10, red: 12, note: "Spawn, then Activate."),

        // Brutes 027-030
        SpawnCard(id: "027", type: .brutes, isRush: false, blue: 1, yellow: 2, orange: 3, red: 4, note: ""),
        SpawnCard(id: "028", type: .brutes, isRush: false, blue: 3, yellow: 4, orange: 5, red: 6, note: ""),
        SpawnCard(id: "029", type: .brutes, isRush: true, blue: 1, yellow: 2, orange: 3, red: 4, note: "Spawn, then Activate."),
        SpawnCard(id: "030", type: .brutes, isRush: true, blue: 2, yellow: 3, orange: 4, red: 5, note: "Spawn, then Activate."),

        // Runners 031-034
        SpawnCard(id: "031", type: .runners, isRush: false, blue: 1, yellow: 2, orange: 3, red: 4, note: ""),
        SpawnCard(id: "032", type: .runners, isRush: false, blue: 1, yellow: 2, orange: 3, red: 4, note: ""),
        SpawnCard(id: "033", type: .runners, isRush: false, blue: 2, yellow: 3, orange: 4, red: 5, note: ""),
        SpawnCard(id: "034", type: .runners, isRush: false, blue: 3, yellow: 4, orange: 5, red: 6, note: ""),

        // Abominations 035-036
        SpawnCard(id: "035", type: .abomination, isRush: false, blue: 1, yellow: 1, orange: 1, red: 1, note: ""),
        SpawnCard(id: "036", type: .abomination, isRush: false, blue: 1, yellow: 1, orange: 1, red: 1, note: ""),

        // Extra Activations 037-040
        SpawnCard(id: "037", type: .extraActivation, isRush: false, blue: 0, yellow: 0, orange: 0, red: 0, note: "All Walkers"),
        SpawnCard(id: "038", type: .extraActivation, isRush: false, blue: 0, yellow: 0, orange: 0, red: 0, note: "All Walkers"),
        SpawnCard(id: "039", type: .extraActivation, isRush: false, blue: 0, yellow: 0, orange: 0, red: 0, note: "All Brutes"),
        SpawnCard(id: "040", type: .extraActivation, isRush: false, blue: 0, yellow: 0, orange: 0, red: 0, note: "All Runners"),
    ]
}

// MARK: - Spawn Deck Manager

/// Manages the spawn deck state including draw pile, discard pile, and game mode
class SpawnDeckManager: ObservableObject {
    @Published var drawPile: [SpawnCard] = []
    @Published var discardPile: [SpawnCard] = []
    @Published var currentCard: SpawnCard?
    @Published var mode: SpawnDeckMode = .hard
    @Published var difficulty: DifficultyLevel = .yellow

    // MARK: - Computed Properties

    /// Number of cards remaining in the draw pile
    var cardsRemaining: Int { drawPile.count }

    /// Number of cards in the discard pile
    var cardsDiscarded: Int { discardPile.count }

    /// Whether there are cards left to draw
    var hasCardsRemaining: Bool { !drawPile.isEmpty }

    /// Whether the deck needs to be reshuffled (draw pile empty but discard has cards)
    var needsReshuffle: Bool { !hasCardsRemaining && !discardPile.isEmpty }

    // MARK: - Initialization

    init() {
        print("🎴 SpawnDeckManager initialized")
    }

    // MARK: - Deck Management

    /// Load and shuffle a fresh deck based on current mode
    func loadDeck() {
        print("🎴 Loading deck in \(mode.rawValue) mode...")

        let cardNumbers = mode.cardRange
        drawPile = SpawnCard.fullDeck.filter { card in
            guard let cardNumber = Int(card.id) else { return false }
            return cardNumbers.contains(cardNumber)
        }

        discardPile = []
        currentCard = nil

        shuffleDeck()

        print("✅ Deck loaded: \(drawPile.count) cards")
    }

    /// Shuffle the draw pile
    func shuffleDeck() {
        print("🔀 Shuffling deck...")
        drawPile.shuffle()
        print("✅ Deck shuffled: \(drawPile.count) cards")
    }

    /// Switch between Easy and Hard mode, then reload the deck
    func switchMode(to newMode: SpawnDeckMode) {
        print("🔄 Switching mode from \(mode.rawValue) to \(newMode.rawValue)")
        mode = newMode
        loadDeck()
    }

    // MARK: - Card Actions

    /// Draw the next card from the draw pile
    /// Returns true if successful, false if draw pile is empty
    @discardableResult
    func drawCard() -> Bool {
        print("🃏 Drawing card...")

        // Move current card to discard if one exists
        if let current = currentCard {
            discardPile.append(current)
            print("  → Previous card #\(current.id) moved to discard pile")
        }

        // Draw from pile
        guard !drawPile.isEmpty else {
            currentCard = nil
            print("❌ Draw pile is empty! Reshuffle needed.")
            return false
        }

        currentCard = drawPile.removeFirst()
        print("✅ Drew card #\(currentCard!.id) (\(currentCard!.type.rawValue))")
        print("  📊 Remaining: \(cardsRemaining), Discarded: \(cardsDiscarded)")
        return true
    }

    /// Get the current card without removing it
    func getCurrentCard() -> SpawnCard? {
        return currentCard
    }

    /// Peek at the top card of the draw pile without drawing it
    func peekTopCard() -> SpawnCard? {
        return drawPile.first
    }

    /// Reset deck by shuffling discard pile back into the draw pile
    func resetDeck() {
        print("♻️ Resetting deck...")

        // Return current card to discard
        if let current = currentCard {
            discardPile.append(current)
            currentCard = nil
        }

        // Shuffle discard pile back into draw pile
        drawPile.append(contentsOf: discardPile)
        discardPile.removeAll()
        shuffleDeck()

        print("✅ Deck reset: \(drawPile.count) cards in draw pile")
    }

    /// Discard the current card without drawing a new one
    func discardCurrentCard() {
        if let current = currentCard {
            discardPile.append(current)
            currentCard = nil
            print("🗑️ Current card #\(current.id) discarded")
        }
    }

    // MARK: - Testing

    /// Run comprehensive tests on deck functionality
    static func runTests() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 SPAWN DECK MANAGER TESTS")
        print(String(repeating: "=", count: 60) + "\n")

        let manager = SpawnDeckManager()

        // Test 1: Load Hard Mode Deck
        print("TEST 1: Load Hard Mode (40 cards)")
        print(String(repeating: "-", count: 60))
        manager.loadDeck()
        assert(manager.cardsRemaining == 40, "Expected 40 cards in hard mode")
        print("✅ PASS: Loaded 40 cards\n")

        // Test 2: Switch to Easy Mode
        print("TEST 2: Switch to Easy Mode (18 cards)")
        print(String(repeating: "-", count: 60))
        manager.switchMode(to: .easy)
        assert(manager.cardsRemaining == 18, "Expected 18 cards in easy mode")
        print("✅ PASS: Loaded 18 cards\n")

        // Test 3: Shuffle Verification
        print("TEST 3: Shuffle Randomization")
        print(String(repeating: "-", count: 60))
        manager.switchMode(to: .hard)
        let firstCard = manager.drawPile.first!.id
        manager.shuffleDeck()
        let shuffledCard = manager.drawPile.first!.id
        print("  First card before shuffle: #\(firstCard)")
        print("  First card after shuffle: #\(shuffledCard)")
        print("✅ PASS: Shuffle executed (randomization may vary)\n")

        // Test 4: Draw Cards
        print("TEST 4: Draw 5 Cards")
        print(String(repeating: "-", count: 60))
        for i in 1...5 {
            let success = manager.drawCard()
            assert(success, "Draw \(i) should succeed")
        }
        assert(manager.cardsRemaining == 35, "Should have 35 cards remaining")
        // After 5 draws: 4 in discard, 1 is current card
        assert(manager.cardsDiscarded == 4, "Should have 4 cards discarded (5th is current)")
        assert(manager.currentCard != nil, "Should have a current card")
        print("✅ PASS: 5 cards drawn correctly (4 discarded, 1 current)\n")

        // Test 5: Current Card Tracking
        print("TEST 5: Current Card Tracking")
        print(String(repeating: "-", count: 60))
        let currentCard = manager.getCurrentCard()
        assert(currentCard != nil, "Should have a current card")
        print("  Current card: #\(currentCard!.id) (\(currentCard!.type.rawValue))")
        print("✅ PASS: Current card tracked\n")

        // Test 6: Draw All Cards
        print("TEST 6: Draw All Remaining Cards")
        print(String(repeating: "-", count: 60))
        var drawCount = 0
        while manager.hasCardsRemaining {
            manager.drawCard()
            drawCount += 1
        }
        print("  Drew \(drawCount) more cards")
        assert(!manager.hasCardsRemaining, "Draw pile should be empty")
        assert(manager.needsReshuffle, "Should need reshuffle")
        print("✅ PASS: All cards drawn, reshuffle needed\n")

        // Test 7: Reset Deck
        print("TEST 7: Reset Deck")
        print(String(repeating: "-", count: 60))
        manager.resetDeck()
        assert(manager.cardsRemaining == 40, "Should have 40 cards after reset")
        assert(manager.cardsDiscarded == 0, "Discard pile should be empty")
        assert(manager.currentCard == nil, "Current card should be nil")
        print("✅ PASS: Deck reset successfully\n")

        // Test 8: Mode Filtering
        print("TEST 8: Mode Filtering (Card Range)")
        print(String(repeating: "-", count: 60))
        manager.switchMode(to: .easy)
        let easyCards = manager.drawPile.map { $0.id }
        let allInRange = easyCards.allSatisfy { id in
            guard let num = Int(id) else { return false }
            return (1...18).contains(num)
        }
        assert(allInRange, "All easy mode cards should be 001-018")
        print("  Easy mode cards: \(easyCards.sorted().joined(separator: ", "))")
        print("✅ PASS: Mode filtering works correctly\n")

        // Test 9: Card Data Integrity
        print("TEST 9: Card Data Integrity")
        print(String(repeating: "-", count: 60))
        manager.loadDeck()
        manager.drawCard()
        if let card = manager.getCurrentCard() {
            print("  Card #\(card.id):")
            print("    Type: \(card.type.rawValue)")
            print("    Rush: \(card.isRush)")
            print("    Blue: \(card.spawnCount(for: .blue))")
            print("    Yellow: \(card.spawnCount(for: .yellow))")
            print("    Orange: \(card.spawnCount(for: .orange))")
            print("    Red: \(card.spawnCount(for: .red))")
            if !card.note.isEmpty {
                print("    Note: \(card.note)")
            }
        }
        print("✅ PASS: Card data accessible\n")

        print(String(repeating: "=", count: 60))
        print("🎉 ALL TESTS PASSED")
        print(String(repeating: "=", count: 60) + "\n")
    }
}
