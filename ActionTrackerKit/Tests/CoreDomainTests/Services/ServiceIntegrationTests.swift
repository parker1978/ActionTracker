//
//  ServiceIntegrationTests.swift
//  CoreDomainTests
//
//  Integration tests for service layer interactions
//  Tests realistic end-to-end scenarios with multiple services
//

import Testing
import SwiftData
import Foundation
@testable import CoreDomain

@MainActor
struct ServiceIntegrationTests {

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

    private func createAllServices(container: ModelContainer) -> (
        deckService: WeaponsDeckService,
        inventoryService: InventoryService,
        customizationService: CustomizationService,
        context: ModelContext
    ) {
        let context = ModelContext(container)
        let deckService = WeaponsDeckService(context: context)
        let inventoryService = InventoryService(context: context, deckService: deckService)
        let customizationService = CustomizationService(context: context)

        return (deckService, inventoryService, customizationService, context)
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

    // MARK: - Draw and Add to Inventory Flow

    @Test func testDrawCardAndAddToActiveInventory() async throws {
        let container = createTestContainer()
        let (deckService, inventoryService, _, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        // Build deck
        let deckState = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        #expect(!deckService.isEmpty(state: deckState))

        // Draw a card
        let drawnCard = try await deckService.draw(from: deckState)
        #expect(drawnCard != nil)

        // Add to inventory
        let error = try await inventoryService.addToActive(
            instance: drawnCard!,
            session: session,
            deckState: deckState
        )

        #expect(error == nil)
        #expect(inventoryService.getActiveCount(session: session) == 1)

        // Verify card was removed from discard (since addToActive removes it)
        let recentDraws = try await deckService.getRecentDraws(state: deckState)
        #expect(!recentDraws.isEmpty)
    }

    @Test func testDrawTwoCardsAndChooseOne() async throws {
        let container = createTestContainer()
        let (deckService, inventoryService, _, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        let deckState = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        // Draw two cards (Flashlight ability)
        let cards = try await deckService.drawTwo(from: deckState)
        #expect(cards.count == 2)

        // Choose first, discard second
        _ = try await inventoryService.addToActive(
            instance: cards[0],
            session: session,
            deckState: deckState
        )

        try await deckService.discard(cards[1], to: deckState)

        #expect(inventoryService.getActiveCount(session: session) == 1)
        #expect(deckState.discardCardIDs.contains(cards[1].id))
    }

    // MARK: - Inventory Full Scenarios

    @Test func testReplaceWeaponWhenInventoryFull() async throws {
        let container = createTestContainer()
        let (deckService, inventoryService, _, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 5)
        let session = createTestSession(context: context)

        let deckState = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        // Fill active slots
        let card1 = try await deckService.draw(from: deckState)
        let card2 = try await deckService.draw(from: deckState)

        _ = try await inventoryService.addToActive(instance: card1!, session: session, deckState: deckState)
        _ = try await inventoryService.addToActive(instance: card2!, session: session, deckState: deckState)

        #expect(inventoryService.getActiveCount(session: session) == 2)

        // Draw new card and replace first weapon
        let newCard = try await deckService.draw(from: deckState)
        let activeItems = inventoryService.getActiveItems(session: session)

        try await inventoryService.replaceWeapon(
            old: activeItems[0],
            new: newCard!,
            session: session,
            discardOldToDeck: true,
            deckState: deckState
        )

        #expect(inventoryService.getActiveCount(session: session) == 2)
        #expect(deckState.discardCardIDs.contains(card1!.id), "Old card should be discarded")
    }

    @Test func testMoveToBackpackWhenActiveFullThenDrawNew() async throws {
        let container = createTestContainer()
        let (deckService, inventoryService, _, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 5)
        let session = createTestSession(context: context)

        let deckState = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        // Fill active slots
        let card1 = try await deckService.draw(from: deckState)
        let card2 = try await deckService.draw(from: deckState)

        _ = try await inventoryService.addToActive(instance: card1!, session: session, deckState: deckState)
        _ = try await inventoryService.addToActive(instance: card2!, session: session, deckState: deckState)

        // Move one to backpack
        let activeItems = inventoryService.getActiveItems(session: session)
        _ = try await inventoryService.moveActiveToBackpack(item: activeItems[0], session: session)

        #expect(inventoryService.getActiveCount(session: session) == 1)
        #expect(inventoryService.getBackpackCount(session: session) == 1)

        // Now can draw and add to active
        let newCard = try await deckService.draw(from: deckState)
        let error = try await inventoryService.addToActive(
            instance: newCard!,
            session: session,
            deckState: deckState
        )

        #expect(error == nil)
        #expect(inventoryService.getActiveCount(session: session) == 2)
    }

    // MARK: - Deck Reshuffling Integration

    @Test func testDrawExhaustsDiscardReshuffles() async throws {
        let container = createTestContainer()
        let (deckService, inventoryService, _, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 2)
        let session = createTestSession(context: context)

        let deckState = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        let totalCards = deckState.remainingCardIDs.count

        // Draw and discard all cards
        for _ in 0..<totalCards {
            if let card = try await deckService.draw(from: deckState) {
                try await deckService.discard(card, to: deckState)
            }
        }

        #expect(deckService.isEmpty(state: deckState))
        #expect(deckState.discardCardIDs.count == totalCards)

        // Next draw should reshuffle
        let card = try await deckService.draw(from: deckState)

        #expect(card != nil)
        #expect(deckState.discardCardIDs.isEmpty, "Discard should be empty after reshuffle")
        #expect(deckState.remainingCardIDs.count == totalCards - 1)
    }

    // MARK: - Customization and Deck Building

    @Test func testBuildDeckWithCustomization() async throws {
        let container = createTestContainer()
        let (deckService, _, customizationService, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        // Create preset with customization
        let preset = try await customizationService.createPreset(
            name: "Custom Deck",
            description: "Test",
            isDefault: false
        )

        // Disable one weapon, increase count of another
        try await customizationService.setCustomization(
            for: definitions[0],
            in: preset,
            isEnabled: false
        )

        try await customizationService.setCustomization(
            for: definitions[1],
            in: preset,
            customCount: 5
        )

        // Apply customizations
        let customized = customizationService.applyCustomizations(
            to: definitions,
            preset: preset
        )

        #expect(customized.count == 2, "Should exclude disabled weapon")
        #expect(customized.contains { $0.definition.id == definitions[1].id && $0.effectiveCount == 5 })
    }

    // MARK: - History and Event Tracking

    @Test func testInventoryHistoryTracksAllOperations() async throws {
        let container = createTestContainer()
        let (deckService, inventoryService, _, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        let deckState = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        let card = try await deckService.draw(from: deckState)!

        // Add to active
        _ = try await inventoryService.addToActive(instance: card, session: session, deckState: deckState)

        // Move to backpack
        let activeItems = inventoryService.getActiveItems(session: session)
        _ = try await inventoryService.moveActiveToBackpack(item: activeItems[0], session: session)

        // Remove
        let backpackItems = inventoryService.getBackpackItems(session: session)
        try await inventoryService.remove(item: backpackItems[0], session: session)

        // Check history
        let history = inventoryService.getHistory(for: session)

        #expect(history.count == 3)
        #expect(history.contains { $0.eventType == "add" })
        #expect(history.contains { $0.eventType == "move" })
        #expect(history.contains { $0.eventType == "remove" })
    }

    @Test func testInventoryHistoryForSpecificWeapon() async throws {
        let container = createTestContainer()
        let (deckService, inventoryService, _, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 2)
        let session = createTestSession(context: context)

        let deckState = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        let card1 = try await deckService.draw(from: deckState)!
        let card2 = try await deckService.draw(from: deckState)!

        _ = try await inventoryService.addToActive(instance: card1, session: session, deckState: deckState)
        _ = try await inventoryService.addToActive(instance: card2, session: session, deckState: deckState)

        let card1History = inventoryService.getHistory(for: card1, in: session)

        #expect(card1History.count == 1)
        #expect(card1History[0].cardInstance?.id == card1.id)
    }

    // MARK: - Preset Export/Import with Active Session

    @Test func testExportPresetWhileSessionActive() async throws {
        let container = createTestContainer()
        let (deckService, inventoryService, customizationService, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        // Create and use preset
        let preset = try await customizationService.createPreset(
            name: "Active Preset",
            description: "Test",
            isDefault: true
        )

        try await customizationService.setCustomization(
            for: definitions[0],
            in: preset,
            customCount: 10
        )

        // Build deck
        _ = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: preset
        )

        // Export while session is active
        let exportData = try customizationService.exportPreset(preset)

        #expect(!exportData.isEmpty)

        let decoded = try JSONDecoder().decode(
            CustomizationService.PresetExportData.self,
            from: exportData
        )

        #expect(decoded.customizations.count == 1)
    }

    // MARK: - Multiple Deck Types

    @Test func testMultipleDeckTypesInSession() async throws {
        let container = createTestContainer()
        let (deckService, _, _, context) = createAllServices(container: container)

        // Create weapons for different deck types
        var startingDefs: [WeaponDefinition] = []
        for i in 0..<2 {
            let def = WeaponDefinition(
                name: "Starting\(i)",
                set: "Test",
                deckType: "starting",
                defaultCount: 2,
                combatStats: "{}"
            )
            context.insert(def)

            for _ in 0..<2 {
                let instance = WeaponCardInstance()
                instance.definition = def
                context.insert(instance)
            }

            startingDefs.append(def)
        }

        var regularDefs: [WeaponDefinition] = []
        for i in 0..<2 {
            let def = WeaponDefinition(
                name: "Regular\(i)",
                set: "Test",
                deckType: "regular",
                defaultCount: 3,
                combatStats: "{}"
            )
            context.insert(def)

            for _ in 0..<3 {
                let instance = WeaponCardInstance()
                instance.definition = def
                context.insert(instance)
            }

            regularDefs.append(def)
        }

        try context.save()

        let session = createTestSession(context: context)

        // Build both decks
        let startingDeck = try await deckService.buildDeck(
            deckType: "starting",
            session: session,
            customization: nil
        )

        let regularDeck = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        #expect(startingDeck.deckType == "starting")
        #expect(regularDeck.deckType == "regular")
        #expect(session.deckStates.count == 2)
    }

    // MARK: - Edge Cases

    @Test func testEmptyDeckHandling() async throws {
        let container = createTestContainer()
        let (deckService, _, _, context) = createAllServices(container: container)

        let session = createTestSession(context: context)

        // Build deck with no weapons
        let deckState = DeckRuntimeState(deckType: "regular")
        deckState.session = session
        deckState.remainingCardIDs = []
        deckState.discardCardIDs = []
        context.insert(deckState)
        try context.save()

        let card = try await deckService.draw(from: deckState)

        #expect(card == nil, "Should handle empty deck gracefully")
    }

    @Test func testAllInventoryActiveModifierIntegration() async throws {
        let container = createTestContainer()
        let (deckService, inventoryService, _, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 3)
        let session = createTestSession(context: context)

        let deckState = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        // Add weapons to both active and backpack
        let card1 = try await deckService.draw(from: deckState)!
        let card2 = try await deckService.draw(from: deckState)!
        let card3 = try await deckService.draw(from: deckState)!

        _ = try await inventoryService.addToActive(instance: card1, session: session, deckState: deckState)
        _ = try await inventoryService.addToActive(instance: card2, session: session, deckState: deckState)
        _ = try await inventoryService.addToBackpack(instance: card3, session: session, deckState: deckState)

        // Without modifier
        session.allInventoryActive = false
        var effectiveActive = inventoryService.getEffectiveActiveWeapons(session: session)
        #expect(effectiveActive.count == 2)

        // With modifier
        session.allInventoryActive = true
        effectiveActive = inventoryService.getEffectiveActiveWeapons(session: session)
        #expect(effectiveActive.count == 3)
    }

    @Test func testReclaim AllDiscardIntegration() async throws {
        let container = createTestContainer()
        let (deckService, inventoryService, _, context) = createAllServices(container: container)

        let definitions = createTestWeapons(context: context, count: 2)
        let session = createTestSession(context: context)

        let deckState = try await deckService.buildDeck(
            deckType: "regular",
            session: session,
            customization: nil
        )

        // Draw and discard several cards
        for _ in 0..<4 {
            if let card = try await deckService.draw(from: deckState) {
                try await deckService.discard(card, to: deckState)
            }
        }

        let discardCount = deckState.discardCardIDs.count
        #expect(discardCount == 4)

        // Reclaim all
        try await deckService.reclaimAllDiscardIntoDeck(state: deckState, shuffle: true)

        #expect(deckState.discardCardIDs.isEmpty)
        #expect(deckState.lastShuffled != nil)
    }
}
