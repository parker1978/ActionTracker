//
//  DeckViewModel.swift
//  SharedUI
//
//  Phase 4: View model for weapon deck operations
//  Wraps WeaponsDeckService and provides @Published state for SwiftUI
//

import SwiftUI
import SwiftData
import CoreDomain
import Observation

/// View model for weapon deck operations
/// Wraps WeaponsDeckService and manages deck state for UI
@MainActor
@Observable
public final class DeckViewModel {
    private let deckService: WeaponsDeckService
    private let context: ModelContext
    private let deckType: String

    // Published state for UI
    public var deckState: DeckRuntimeState?
    public var recentDraws: [WeaponCardInstance] = []
    public var isLoading = false
    public var errorMessage: String?

    // Computed properties
    public var remainingCount: Int {
        deckState?.remainingCardIDs.count ?? 0
    }

    public var discardCount: Int {
        deckState?.discardCardIDs.count ?? 0
    }

    public var isEmpty: Bool {
        remainingCount == 0
    }

    public init(
        deckType: String,
        deckService: WeaponsDeckService,
        context: ModelContext
    ) {
        self.deckType = deckType
        self.deckService = deckService
        self.context = context
    }

    // MARK: - Deck Loading

    /// Load or create deck for the given session
    public func loadDeck(for session: GameSession, preset: DeckPreset? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            deckState = try await deckService.loadOrCreateDeck(
                deckType: deckType,
                session: session,
                customization: preset
            )
            await loadRecentDraws()
        } catch {
            errorMessage = "Failed to load deck: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Drawing Cards

    /// Draw a single card
    public func draw() async -> WeaponCardInstance? {
        guard let state = deckState else { return nil }

        do {
            let card = try await deckService.draw(from: state)
            await loadRecentDraws()
            return card
        } catch {
            errorMessage = "Failed to draw card: \(error.localizedDescription)"
            return nil
        }
    }

    /// Draw two cards (for Flashlight ability)
    public func drawTwo() async -> [WeaponCardInstance] {
        guard let state = deckState else { return [] }

        do {
            let cards = try await deckService.drawTwo(from: state)
            await loadRecentDraws()
            return cards
        } catch {
            errorMessage = "Failed to draw cards: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - Shuffling

    /// Shuffle the deck
    public func shuffle() async {
        guard let state = deckState else { return }

        do {
            try await deckService.shuffleDeck(state: state)
        } catch {
            errorMessage = "Failed to shuffle deck: \(error.localizedDescription)"
        }
    }

    // MARK: - Discard Management

    /// Discard a card
    public func discard(_ instance: WeaponCardInstance) async {
        guard let state = deckState else { return }

        do {
            try await deckService.discard(instance, to: state)
        } catch {
            errorMessage = "Failed to discard card: \(error.localizedDescription)"
        }
    }

    /// Return a card from discard to top of deck
    public func returnToTop(_ instance: WeaponCardInstance) async {
        guard let state = deckState else { return }

        do {
            try await deckService.returnFromDiscardToTop(instance, in: state)
        } catch {
            errorMessage = "Failed to return card to top: \(error.localizedDescription)"
        }
    }

    /// Return a card from discard to bottom of deck
    public func returnToBottom(_ instance: WeaponCardInstance) async {
        guard let state = deckState else { return }

        do {
            try await deckService.returnFromDiscardToBottom(instance, in: state)
        } catch {
            errorMessage = "Failed to return card to bottom: \(error.localizedDescription)"
        }
    }

    /// Reclaim all discard into deck and shuffle
    public func reclaimAllDiscard(shuffle: Bool = true) async {
        guard let state = deckState else { return }

        do {
            try await deckService.reclaimAllDiscardIntoDeck(state: state, shuffle: shuffle)
        } catch {
            errorMessage = "Failed to reclaim discard: \(error.localizedDescription)"
        }
    }

    // MARK: - Deck Reset

    /// Reset the deck (rebuild and shuffle)
    public func reset(for session: GameSession, preset: DeckPreset? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            // Delete existing deck state
            if let state = deckState {
                context.delete(state)
                try context.save()
            }

            // Create new deck
            deckState = try await deckService.buildDeck(
                deckType: deckType,
                session: session,
                customization: preset
            )

            await loadRecentDraws()
        } catch {
            errorMessage = "Failed to reset deck: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    /// Load recent draws for display
    private func loadRecentDraws() async {
        guard let state = deckState else {
            recentDraws = []
            return
        }

        do {
            recentDraws = try await deckService.getRecentDraws(state: state)
        } catch {
            print("⚠️ Failed to load recent draws: \(error)")
            recentDraws = []
        }
    }

    // MARK: - Deck Contents Access

    /// Get all remaining card instances (for deck contents view)
    public func getRemainingCards() async -> [WeaponCardInstance] {
        guard let state = deckState else { return [] }

        var cards: [WeaponCardInstance] = []
        for id in state.remainingCardIDs {
            let descriptor = FetchDescriptor<WeaponCardInstance>(
                predicate: #Predicate { $0.id == id }
            )
            if let instance = try? context.fetch(descriptor).first {
                cards.append(instance)
            }
        }
        return cards
    }

    /// Get all discard pile instances (for discard view)
    public func getDiscardCards() async -> [WeaponCardInstance] {
        guard let state = deckState else { return [] }

        var cards: [WeaponCardInstance] = []
        for id in state.discardCardIDs {
            let descriptor = FetchDescriptor<WeaponCardInstance>(
                predicate: #Predicate { $0.id == id }
            )
            if let instance = try? context.fetch(descriptor).first {
                cards.append(instance)
            }
        }
        return cards
    }
}
