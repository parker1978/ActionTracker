//
//  WeaponsDeckServiceTests.swift
//  CoreDomainTests
//
//  Tests for WeaponsDeckService
//  Validates deck building, shuffling, drawing, and state management
//

import Testing
import SwiftData
import Foundation
@testable import CoreDomain

@MainActor
struct WeaponsDeckServiceTests {

    // MARK: - Test Setup

    private func createTestContainer() -> ModelContainer {
        let schema = Schema([
            WeaponDefinition.self,
            WeaponCardInstance.self,
            DeckRuntimeState.self,
            GameSession.self,
            Character.self,
            DeckPreset.self,
            DeckCustomization.self,
            WeaponInventoryItem.self,
            InventoryEvent.self
        ])

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    private func createTestService(container: ModelContainer) -> WeaponsDeckService {
        let context = ModelContext(container)
        return WeaponsDeckService(context: context)
    }

    private func createTestWeapons(context: ModelContext, count: Int = 5) -> [WeaponDefinition] {
        var definitions: [WeaponDefinition] = []

        for i in 0..<count {
            let definition = WeaponDefinition(
                name: "Weapon\(i)",
                set: "Test Set",
                deckType: "regular",
                defaultCount: 3,
                combatStats: "{}"
            )
            context.insert(definition)

            // Create card instances
            for _ in 0..<3 {
                let instance = WeaponCardInstance()
                instance.definition = definition
                context.insert(instance)
            }

            definitions.append(definition)
        }

        try! context.save()
        return definitions
    }

    private func createTestSession(context: ModelContext) -> GameSession {
        let character = Character(
            name: "Test Character",
            health: 10,
            startingWeapons: "Test Weapon",
            blueSkills: "Blue Skill",
            yellowSkills: "Yellow Skill",
            orangeSkills: "Orange 1;Orange 2",
            redSkills: "Red 1;Red 2;Red 3"
        )
        context.insert(character)

        let session = GameSession(character: character)
        context.insert(session)

        try! context.save()
        return session
    }

    // MARK: - Deck Building Tests

    @Test func testBuildDeckCreatesStateWithCards() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context)
        let session = createTestSession(context: context)

        let deckState = try await service.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        #expect(deckState.deckType == "regular")
        #expect(deckState.remainingCardIDs.count == 15) // 5 weapons × 3 instances
        #expect(deckState.discardCardIDs.isEmpty)
        #expect(deckState.lastShuffled != nil)
    }

    @Test func testBuildDeckReturnsExistingState() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context)
        let session = createTestSession(context: context)

        let firstDeck = try await service.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        let secondDeck = try await service.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        #expect(firstDeck.id == secondDeck.id)
    }

    @Test func testLoadOrCreateDeckCreatesNewDeck() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context)
        let session = createTestSession(context: context)

        let deckState = try await service.loadOrCreateDeck(
            deckType: "starting",
            session: session,
            customization: nil
        )

        #expect(deckState.deckType == "starting")
        #expect(!deckState.remainingCardIDs.isEmpty)
    }

    // MARK: - Shuffle Tests

    @Test func testShuffleDeckWithSingleCard() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let session = createTestSession(context: context)
        let deckState = DeckRuntimeState(deckType: "regular")
        deckState.session = session

        // Create single card
        let definition = WeaponDefinition(
            name: "Single Weapon",
            set: "Test",
            deckType: "regular",
            defaultCount: 1,
            combatStats: "{}"
        )
        context.insert(definition)

        let instance = WeaponCardInstance()
        instance.definition = definition
        context.insert(instance)

        deckState.remainingCardIDs = [instance.id]
        context.insert(deckState)
        try context.save()

        try await service.shuffleDeck(state: deckState)

        #expect(deckState.remainingCardIDs.count == 1)
        #expect(deckState.lastShuffled != nil)
    }

    @Test func testShuffleDeckPreventsBackToBackDuplicates() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let session = createTestSession(context: context)

        // Create deck with multiple copies of same weapon
        let definition1 = WeaponDefinition(
            name: "Duplicate Weapon",
            set: "Test",
            deckType: "regular",
            defaultCount: 5,
            combatStats: "{}"
        )
        context.insert(definition1)

        let definition2 = WeaponDefinition(
            name: "Other Weapon",
            set: "Test",
            deckType: "regular",
            defaultCount: 3,
            combatStats: "{}"
        )
        context.insert(definition2)

        var cardIDs: [UUID] = []

        for _ in 0..<5 {
            let instance = WeaponCardInstance()
            instance.definition = definition1
            context.insert(instance)
            cardIDs.append(instance.id)
        }

        for _ in 0..<3 {
            let instance = WeaponCardInstance()
            instance.definition = definition2
            context.insert(instance)
            cardIDs.append(instance.id)
        }

        let deckState = DeckRuntimeState(deckType: "regular")
        deckState.session = session
        deckState.remainingCardIDs = cardIDs
        context.insert(deckState)
        try context.save()

        try await service.shuffleDeck(state: deckState)

        // Verify no back-to-back duplicates
        let shuffled = deckState.remainingCardIDs
        var hasDuplicates = false

        let descriptor = FetchDescriptor<WeaponCardInstance>()
        let allInstances = try context.fetch(descriptor)
        let instanceMap = Dictionary(uniqueKeysWithValues: allInstances.map { ($0.id, $0) })

        for i in 0..<(shuffled.count - 1) {
            let currentName = instanceMap[shuffled[i]]?.definition?.name
            let nextName = instanceMap[shuffled[i + 1]]?.definition?.name

            if currentName == nextName && currentName != nil {
                hasDuplicates = true
                break
            }
        }

        #expect(!hasDuplicates, "Shuffle should prevent back-to-back duplicates")
    }

    // MARK: - Draw Tests

    @Test func testDrawRemovesCardFromDeck() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        let deckState = try await service.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        let initialCount = deckState.remainingCardIDs.count
        let drawnCard = try await service.draw(from: deckState)

        #expect(drawnCard != nil)
        #expect(deckState.remainingCardIDs.count == initialCount - 1)
        #expect(deckState.recentDrawIDs.contains(drawnCard!.id))
        #expect(deckState.lastDrawn != nil)
    }

    @Test func testDrawTwoReturns TwoCards() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        let deckState = try await service.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        let cards = try await service.drawTwo(from: deckState)

        #expect(cards.count == 2)
        #expect(cards[0].id != cards[1].id)
    }

    @Test func testDrawFromEmptyDeckReshufflesDiscard() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 2)
        let session = createTestSession(context: context)

        let deckState = DeckRuntimeState(deckType: "regular")
        deckState.session = session

        // Setup: empty remaining, populated discard
        let instance1 = WeaponCardInstance()
        let instance2 = WeaponCardInstance()
        instance1.definition = definitions[0]
        instance2.definition = definitions[1]
        context.insert(instance1)
        context.insert(instance2)

        deckState.remainingCardIDs = []
        deckState.discardCardIDs = [instance1.id, instance2.id]
        context.insert(deckState)
        try context.save()

        let drawnCard = try await service.draw(from: deckState)

        #expect(drawnCard != nil)
        #expect(deckState.discardCardIDs.isEmpty)
        #expect(deckState.remainingCardIDs.count == 1)  // One left after draw
    }

    @Test func testRecentDrawsKeepsLast3() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 5)
        let session = createTestSession(context: context)

        let deckState = try await service.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        // Draw 5 cards
        for _ in 0..<5 {
            _ = try await service.draw(from: deckState)
        }

        #expect(deckState.recentDrawIDs.count == 3, "Should keep only last 3 draws")
    }

    // MARK: - Discard Tests

    @Test func testDiscardAddsToDiscardPile() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 2)
        let session = createTestSession(context: context)

        let deckState = try await service.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        let drawnCard = try await service.draw(from: deckState)
        #expect(drawnCard != nil)

        try await service.discard(drawnCard!, to: deckState)

        #expect(deckState.discardCardIDs.contains(drawnCard!.id))
        #expect(deckState.discardCardIDs.first == drawnCard!.id, "Newest should be first")
    }

    @Test func testRemoveFromDiscard() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 2)
        let session = createTestSession(context: context)

        let deckState = DeckRuntimeState(deckType: "regular")
        deckState.session = session

        let instance = WeaponCardInstance()
        instance.definition = definitions[0]
        context.insert(instance)

        deckState.discardCardIDs = [instance.id]
        context.insert(deckState)
        try context.save()

        try await service.removeFromDiscard(instance, in: deckState)

        #expect(deckState.discardCardIDs.isEmpty)
    }

    @Test func testReturnFromDiscardToTop() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 2)
        let session = createTestSession(context: context)

        let deckState = DeckRuntimeState(deckType: "regular")
        deckState.session = session

        let instance = WeaponCardInstance()
        instance.definition = definitions[0]
        context.insert(instance)

        deckState.remainingCardIDs = [UUID(), UUID()]  // Some existing cards
        deckState.discardCardIDs = [instance.id]
        context.insert(deckState)
        try context.save()

        try await service.returnFromDiscardToTop(instance, in: deckState)

        #expect(!deckState.discardCardIDs.contains(instance.id))
        #expect(deckState.remainingCardIDs.first == instance.id, "Should be at top")
    }

    @Test func testReturnFromDiscardToBottom() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 2)
        let session = createTestSession(context: context)

        let deckState = DeckRuntimeState(deckType: "regular")
        deckState.session = session

        let instance = WeaponCardInstance()
        instance.definition = definitions[0]
        context.insert(instance)

        deckState.remainingCardIDs = [UUID(), UUID()]
        deckState.discardCardIDs = [instance.id]
        context.insert(deckState)
        try context.save()

        try await service.returnFromDiscardToBottom(instance, in: deckState)

        #expect(!deckState.discardCardIDs.contains(instance.id))
        #expect(deckState.remainingCardIDs.last == instance.id, "Should be at bottom")
    }

    // MARK: - Deck Reordering Tests

    @Test func testMoveCardToTop() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        let deckState = try await service.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        let cardToMove = deckState.remainingCardIDs[5]  // Middle card

        let instance = WeaponCardInstance()
        instance.id = cardToMove

        try await service.moveCardToTop(instance, in: deckState)

        #expect(deckState.remainingCardIDs.first == cardToMove)
    }

    @Test func testMoveCardToBottom() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        let deckState = try await service.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        let cardToMove = deckState.remainingCardIDs[2]

        let instance = WeaponCardInstance()
        instance.id = cardToMove

        try await service.moveCardToBottom(instance, in: deckState)

        #expect(deckState.remainingCardIDs.last == cardToMove)
    }

    @Test func testReclaimAllDiscardIntoDeck() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 2)
        let session = createTestSession(context: context)

        let deckState = DeckRuntimeState(deckType: "regular")
        deckState.session = session
        deckState.remainingCardIDs = [UUID()]
        deckState.discardCardIDs = [UUID(), UUID(), UUID()]
        context.insert(deckState)
        try context.save()

        let initialDiscard = deckState.discardCardIDs.count

        try await service.reclaimAllDiscardIntoDeck(state: deckState, shuffle: false)

        #expect(deckState.discardCardIDs.isEmpty)
        #expect(deckState.remainingCardIDs.count == 1 + initialDiscard)
    }

    // MARK: - Computed Properties Tests

    @Test func testRemainingCount() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        let deckState = try await service.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        let count = service.remainingCount(state: deckState)

        #expect(count == 9)  // 3 weapons × 3 instances
    }

    @Test func testIsEmpty() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let service = createTestService(container: container)

        let session = createTestSession(context: context)

        let deckState = DeckRuntimeState(deckType: "regular")
        deckState.session = session
        deckState.remainingCardIDs = []
        context.insert(deckState)
        try context.save()

        #expect(service.isEmpty(state: deckState))
    }
}
