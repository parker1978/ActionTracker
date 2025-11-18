//
//  WeaponsDeckService.swift
//  CoreDomain
//
//  Phase 2: Service layer for deck runtime operations
//  Manages deck building, shuffling, drawing, and persistence
//

import SwiftData
import Foundation

/// Service for managing weapon deck runtime state and operations
/// Builds decks from SwiftData models and persists state for game resume
@MainActor
public class WeaponsDeckService {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Deck Building

    /// Builds a deck for the specified type and session
    /// Applies customizations if provided, otherwise uses defaults
    public func buildDeck(
        deckType: String,
        session: GameSession,
        customization: DeckPreset? = nil
    ) async throws -> DeckRuntimeState {
        // Check if deck state already exists
        if let existing = try getDeckState(session: session, deckType: deckType) {
            return existing
        }

        // Fetch weapon definitions for this deck type
        let descriptor = FetchDescriptor<WeaponDefinition>(
            predicate: #Predicate { definition in
                definition.deckType == deckType && !definition.isDeprecated
            }
        )
        let definitions = try context.fetch(descriptor)

        // Build deck with card instances
        var cardInstanceIDs: [UUID] = []

        for definition in definitions {
            // Determine count (customization or default)
            let count = definition.defaultCount

            // Get this weapon's card instances
            let instances = definition.cardInstances.prefix(count)
            cardInstanceIDs.append(contentsOf: instances.map { $0.id })
        }

        // Create deck state
        let deckState = DeckRuntimeState(deckType: deckType)
        deckState.session = session
        deckState.remainingCardIDs = cardInstanceIDs
        deckState.lastShuffled = Date()

        // Shuffle the deck
        try await shuffleDeck(state: deckState)

        context.insert(deckState)
        try context.save()

        return deckState
    }

    // MARK: - Deck State Management

    /// Get existing deck state for session and deck type
    public func getDeckState(session: GameSession, deckType: String) throws -> DeckRuntimeState? {
        return session.deckStates.first { $0.deckType == deckType }
    }

    /// Load deck state or create new one
    public func loadOrCreateDeck(
        deckType: String,
        session: GameSession,
        customization: DeckPreset? = nil
    ) async throws -> DeckRuntimeState {
        if let existing = try getDeckState(session: session, deckType: deckType) {
            return existing
        }

        return try await buildDeck(deckType: deckType, session: session, customization: customization)
    }

    // MARK: - Shuffle Algorithm

    /// Shuffle deck using the proven algorithm from WeaponDeckState
    /// CRITICAL: This is a direct port - prevents back-to-back duplicates
    /// DO NOT MODIFY - proven to work without infinite loops
    public func shuffleDeck(state: DeckRuntimeState) async throws {
        var remaining = state.remainingCardIDs

        // Need at least 2 cards to check for duplicates
        guard remaining.count > 1 else {
            remaining.shuffle()
            state.remainingCardIDs = remaining
            state.lastShuffled = Date()
            try context.save()
            return
        }

        // Initial shuffle
        remaining.shuffle()

        // Fix duplicates in a single pass
        // Fetch instances once for name comparison
        let instanceLookup = try await getCardInstanceLookup(ids: remaining)

        var i = 0
        while i < remaining.count - 1 {
            let currentName = instanceLookup[remaining[i]]?.definition?.name
            let nextName = instanceLookup[remaining[i + 1]]?.definition?.name

            if currentName == nextName {
                // Find next card that's DIFFERENT from current
                var swapIndex = i + 2
                while swapIndex < remaining.count {
                    let swapName = instanceLookup[remaining[swapIndex]]?.definition?.name
                    if swapName != currentName {
                        break
                    }
                    swapIndex += 1
                }

                if swapIndex < remaining.count {
                    // Found a different card, swap it with position i+1
                    remaining.swapAt(i + 1, swapIndex)
                    // Don't increment i - recheck this position in case swap created new duplicate
                } else if i > 0 {
                    let firstCardName = instanceLookup[remaining[0]]?.definition?.name
                    if firstCardName != currentName {
                        // All remaining cards are identical, wrap to start if position 0 is different
                        remaining.swapAt(i + 1, 0)
                        // Don't increment i - recheck this position
                    } else {
                        // Can't fix this duplicate (all cards are the same), move on
                        i += 1
                    }
                } else {
                    // Can't fix this duplicate (all cards are the same), move on
                    i += 1
                }
            } else {
                i += 1
            }
        }

        state.remainingCardIDs = remaining
        state.lastShuffled = Date()
        try context.save()
    }

    // MARK: - Drawing Cards

    /// Draw a single card from the deck
    /// Automatically reshuffles discard if deck is empty
    public func draw(from state: DeckRuntimeState) async throws -> WeaponCardInstance? {
        if state.remainingCardIDs.isEmpty {
            try await reshuffleDiscardIntoDeck(state: state)
        }

        guard !state.remainingCardIDs.isEmpty else { return nil }

        let cardID = state.remainingCardIDs.removeFirst()

        // Update recent draws (keep last 3)
        state.recentDrawIDs.insert(cardID, at: 0)
        if state.recentDrawIDs.count > 3 {
            state.recentDrawIDs = Array(state.recentDrawIDs.prefix(3))
        }

        state.lastDrawn = Date()
        try context.save()

        // Fetch the actual card instance
        let descriptor = FetchDescriptor<WeaponCardInstance>(
            predicate: #Predicate { $0.id == cardID }
        )
        return try context.fetch(descriptor).first
    }

    /// Draw two cards (for Flashlight ability)
    public func drawTwo(from state: DeckRuntimeState) async throws -> [WeaponCardInstance] {
        var cards: [WeaponCardInstance] = []

        if let first = try await draw(from: state) {
            cards.append(first)
        }

        if let second = try await draw(from: state) {
            cards.append(second)
        }

        return cards
    }

    // MARK: - Discard Management

    /// Add a card to the discard pile
    public func discard(_ instance: WeaponCardInstance, to state: DeckRuntimeState) async throws {
        state.discardCardIDs.insert(instance.id, at: 0) // Newest first
        try context.save()
    }

    /// Return a card from discard to top of deck
    public func returnFromDiscardToTop(_ instance: WeaponCardInstance, in state: DeckRuntimeState) async throws {
        if let index = state.discardCardIDs.firstIndex(of: instance.id) {
            state.discardCardIDs.remove(at: index)
            state.remainingCardIDs.insert(instance.id, at: 0)
            try context.save()
        }
    }

    /// Return a card from discard to bottom of deck
    public func returnFromDiscardToBottom(_ instance: WeaponCardInstance, in state: DeckRuntimeState) async throws {
        if let index = state.discardCardIDs.firstIndex(of: instance.id) {
            state.discardCardIDs.remove(at: index)
            state.remainingCardIDs.append(instance.id)
            try context.save()
        }
    }

    /// Remove a card from discard pile (e.g., when adding to inventory)
    public func removeFromDiscard(_ instance: WeaponCardInstance, in state: DeckRuntimeState) async throws {
        if let index = state.discardCardIDs.firstIndex(of: instance.id) {
            state.discardCardIDs.remove(at: index)
            try context.save()
        }
    }

    /// Remove a card from remaining deck (e.g., when adding to inventory)
    public func removeFromRemaining(_ instance: WeaponCardInstance, in state: DeckRuntimeState) async throws {
        if let index = state.remainingCardIDs.firstIndex(of: instance.id) {
            state.remainingCardIDs.remove(at: index)
            try context.save()
        }
    }

    // MARK: - Deck Reordering

    /// Move a card from remaining deck to the top
    public func moveCardToTop(_ instance: WeaponCardInstance, in state: DeckRuntimeState) async throws {
        if let index = state.remainingCardIDs.firstIndex(of: instance.id) {
            state.remainingCardIDs.remove(at: index)
            state.remainingCardIDs.insert(instance.id, at: 0)
            try context.save()
        }
    }

    /// Move a card from remaining deck to the bottom
    public func moveCardToBottom(_ instance: WeaponCardInstance, in state: DeckRuntimeState) async throws {
        if let index = state.remainingCardIDs.firstIndex(of: instance.id) {
            state.remainingCardIDs.remove(at: index)
            state.remainingCardIDs.append(instance.id)
            try context.save()
        }
    }

    /// Move a card from remaining deck to discard pile
    public func discardFromDeck(_ instance: WeaponCardInstance, in state: DeckRuntimeState) async throws {
        if let index = state.remainingCardIDs.firstIndex(of: instance.id) {
            state.remainingCardIDs.remove(at: index)
            state.discardCardIDs.insert(instance.id, at: 0)
            try context.save()
        }
    }

    /// Move all cards from discard back into deck and shuffle
    public func reclaimAllDiscardIntoDeck(state: DeckRuntimeState, shuffle: Bool = true) async throws {
        state.remainingCardIDs.append(contentsOf: state.discardCardIDs)
        state.discardCardIDs.removeAll()

        if shuffle {
            try await shuffleDeck(state: state)
        } else {
            try context.save()
        }
    }

    /// Clear discard pile
    public func clearDiscard(state: DeckRuntimeState) async throws {
        state.discardCardIDs.removeAll()
        try context.save()
    }

    // MARK: - Private Helpers

    /// Reshuffle discard pile back into deck
    private func reshuffleDiscardIntoDeck(state: DeckRuntimeState) async throws {
        guard !state.discardCardIDs.isEmpty else {
            // Emergency: rebuild deck if both empty
            // This shouldn't happen in normal gameplay
            print("⚠️ Both deck and discard empty - rebuilding deck")
            return
        }

        state.remainingCardIDs = state.discardCardIDs
        state.discardCardIDs.removeAll()
        try await shuffleDeck(state: state)
    }

    /// Create lookup dictionary for card instances
    private func getCardInstanceLookup(ids: [UUID]) async throws -> [UUID: WeaponCardInstance] {
        // Fetch all instances individually to avoid predicate complexity with arrays
        var lookup: [UUID: WeaponCardInstance] = [:]
        for id in ids {
            let descriptor = FetchDescriptor<WeaponCardInstance>(
                predicate: #Predicate { $0.id == id }
            )
            if let instance = try context.fetch(descriptor).first {
                lookup[id] = instance
            }
        }
        return lookup
    }

    // MARK: - Computed Properties

    /// Get remaining count
    public func remainingCount(state: DeckRuntimeState) -> Int {
        state.remainingCardIDs.count
    }

    /// Get discard count
    public func discardCount(state: DeckRuntimeState) -> Int {
        state.discardCardIDs.count
    }

    /// Check if deck is empty
    public func isEmpty(state: DeckRuntimeState) -> Bool {
        state.remainingCardIDs.isEmpty
    }

    /// Get recent draws as card instances
    public func getRecentDraws(state: DeckRuntimeState) async throws -> [WeaponCardInstance] {
        guard !state.recentDrawIDs.isEmpty else { return [] }

        // Fetch instances individually to avoid predicate complexity
        var instances: [WeaponCardInstance] = []
        for id in state.recentDrawIDs {
            let descriptor = FetchDescriptor<WeaponCardInstance>(
                predicate: #Predicate { $0.id == id }
            )
            if let instance = try context.fetch(descriptor).first {
                instances.append(instance)
            }
        }

        return instances
    }
}
