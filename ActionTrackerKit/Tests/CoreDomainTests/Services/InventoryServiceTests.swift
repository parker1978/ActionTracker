//
//  InventoryServiceTests.swift
//  CoreDomainTests
//
//  Tests for InventoryService
//  Validates slot enforcement, add/remove/move operations, and history tracking
//

import Testing
import SwiftData
import Foundation
@testable import CoreDomain

@MainActor
struct InventoryServiceTests {

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

    private func createTestServices(container: ModelContainer) -> (InventoryService, WeaponsDeckService) {
        let context = ModelContext(container)
        let deckService = WeaponsDeckService(context: context)
        let inventoryService = InventoryService(context: context, deckService: deckService)
        return (inventoryService, deckService)
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

    private func createTestWeaponInstance(context: ModelContext, name: String = "Test Weapon") -> WeaponCardInstance {
        let definition = WeaponDefinition(
            name: name,
            set: "Test Set",
            deckType: "regular",
            defaultCount: 1,
            combatStats: "{}"
        )
        context.insert(definition)

        let instance = WeaponCardInstance()
        instance.definition = definition
        context.insert(instance)

        try! context.save()
        return instance
    }

    // MARK: - Capacity Tests

    @Test func testGetActiveCapacity() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let capacity = service.getActiveCapacity(for: session)

        #expect(capacity == 2, "Active capacity should always be 2 hands")
    }

    @Test func testGetBackpackCapacityDefault() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let capacity = service.getBackpackCapacity(for: session)

        #expect(capacity == 3, "Default backpack capacity should be 3")
    }

    @Test func testGetBackpackCapacityWithExtraSlots() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        session.extraInventorySlots = 2

        let capacity = service.getBackpackCapacity(for: session)

        #expect(capacity == 5, "Backpack capacity should be 3 + 2 = 5")
    }

    @Test func testCanAddToActive() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        #expect(service.canAddToActive(session: session))

        // Add 2 items to fill active slots
        let instance1 = createTestWeaponInstance(context: context, name: "Weapon 1")
        let instance2 = createTestWeaponInstance(context: context, name: "Weapon 2")

        _ = try await service.addToActive(instance: instance1, session: session, deckState: nil)
        _ = try await service.addToActive(instance: instance2, session: session, deckState: nil)

        #expect(!service.canAddToActive(session: session), "Should be full after 2 items")
    }

    @Test func testCanAddToBackpack() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        #expect(service.canAddToBackpack(session: session))

        // Fill backpack (3 slots)
        for i in 0..<3 {
            let instance = createTestWeaponInstance(context: context, name: "Weapon \(i)")
            _ = try await service.addToBackpack(instance: instance, session: session, deckState: nil)
        }

        #expect(!service.canAddToBackpack(session: session), "Should be full after 3 items")
    }

    // MARK: - Add to Active Tests

    @Test func testAddToActiveSuccess() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let instance = createTestWeaponInstance(context: context)

        let error = try await service.addToActive(instance: instance, session: session, deckState: nil)

        #expect(error == nil, "Should succeed")
        #expect(service.getActiveCount(session: session) == 1)

        let activeItems = service.getActiveItems(session: session)
        #expect(activeItems.count == 1)
        #expect(activeItems[0].slotType == "active")
        #expect(activeItems[0].cardInstance?.id == instance.id)
    }

    @Test func testAddToActiveFailsWhenFull() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        // Fill active slots
        let instance1 = createTestWeaponInstance(context: context, name: "Weapon 1")
        let instance2 = createTestWeaponInstance(context: context, name: "Weapon 2")
        _ = try await service.addToActive(instance: instance1, session: session, deckState: nil)
        _ = try await service.addToActive(instance: instance2, session: session, deckState: nil)

        // Try to add third
        let instance3 = createTestWeaponInstance(context: context, name: "Weapon 3")
        let error = try await service.addToActive(instance: instance3, session: session, deckState: nil)

        #expect(error != nil, "Should return error message")
        #expect(error?.contains("Active slots full") == true)
    }

    @Test func testAddToActiveRecordsEvent() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let instance = createTestWeaponInstance(context: context)

        _ = try await service.addToActive(instance: instance, session: session, deckState: nil)

        let history = service.getHistory(for: session)
        #expect(history.count == 1)
        #expect(history[0].eventType == "add")
        #expect(history[0].slotType == "active")
        #expect(history[0].cardInstance?.id == instance.id)
    }

    // MARK: - Add to Backpack Tests

    @Test func testAddToBackpackSuccess() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let instance = createTestWeaponInstance(context: context)

        let error = try await service.addToBackpack(instance: instance, session: session, deckState: nil)

        #expect(error == nil, "Should succeed")
        #expect(service.getBackpackCount(session: session) == 1)

        let backpackItems = service.getBackpackItems(session: session)
        #expect(backpackItems.count == 1)
        #expect(backpackItems[0].slotType == "backpack")
    }

    @Test func testAddToBackpackFailsWhenFull() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        // Fill backpack
        for i in 0..<3 {
            let instance = createTestWeaponInstance(context: context, name: "Weapon \(i)")
            _ = try await service.addToBackpack(instance: instance, session: session, deckState: nil)
        }

        // Try to add fourth
        let instance4 = createTestWeaponInstance(context: context, name: "Weapon 4")
        let error = try await service.addToBackpack(instance: instance4, session: session, deckState: nil)

        #expect(error != nil, "Should return error message")
        #expect(error?.contains("Backpack full") == true)
    }

    @Test func testAddToBackpackRespectsExtraSlots() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        session.extraInventorySlots = 2  // Now 5 total

        // Fill 5 slots
        for i in 0..<5 {
            let instance = createTestWeaponInstance(context: context, name: "Weapon \(i)")
            let error = try await service.addToBackpack(instance: instance, session: session, deckState: nil)
            #expect(error == nil, "Should accept all 5 items")
        }

        // Try sixth
        let instance6 = createTestWeaponInstance(context: context, name: "Weapon 6")
        let error = try await service.addToBackpack(instance: instance6, session: session, deckState: nil)

        #expect(error != nil, "Should reject 6th item")
    }

    // MARK: - Remove Tests

    @Test func testRemoveFromInventory() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let instance = createTestWeaponInstance(context: context)
        _ = try await service.addToActive(instance: instance, session: session, deckState: nil)

        let items = service.getActiveItems(session: session)
        #expect(items.count == 1)

        try await service.remove(item: items[0], session: session, discardToDeck: false, deckState: nil)

        #expect(service.getActiveCount(session: session) == 0)
    }

    @Test func testRemoveRecordsEvent() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let instance = createTestWeaponInstance(context: context)
        _ = try await service.addToActive(instance: instance, session: session, deckState: nil)

        let items = service.getActiveItems(session: session)
        try await service.remove(item: items[0], session: session, discardToDeck: false, deckState: nil)

        let history = service.getHistory(for: session)
        let removeEvent = history.first { $0.eventType == "remove" }
        #expect(removeEvent != nil)
    }

    // MARK: - Move Operations Tests

    @Test func testMoveActiveToBackpack() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let instance = createTestWeaponInstance(context: context)
        _ = try await service.addToActive(instance: instance, session: session, deckState: nil)

        let activeItems = service.getActiveItems(session: session)
        let error = try await service.moveActiveToBackpack(item: activeItems[0], session: session)

        #expect(error == nil, "Should succeed")
        #expect(service.getActiveCount(session: session) == 0)
        #expect(service.getBackpackCount(session: session) == 1)

        let backpackItems = service.getBackpackItems(session: session)
        #expect(backpackItems[0].cardInstance?.id == instance.id)
    }

    @Test func testMoveActiveToBackpackFailsWhenBackpackFull() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        // Fill backpack
        for i in 0..<3 {
            let instance = createTestWeaponInstance(context: context, name: "Backpack \(i)")
            _ = try await service.addToBackpack(instance: instance, session: session, deckState: nil)
        }

        // Add to active
        let activeInstance = createTestWeaponInstance(context: context, name: "Active Weapon")
        _ = try await service.addToActive(instance: activeInstance, session: session, deckState: nil)

        let activeItems = service.getActiveItems(session: session)
        let error = try await service.moveActiveToBackpack(item: activeItems[0], session: session)

        #expect(error != nil, "Should fail with full backpack")
        #expect(error?.contains("Backpack full") == true)
    }

    @Test func testMoveBackpackToActive() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let instance = createTestWeaponInstance(context: context)
        _ = try await service.addToBackpack(instance: instance, session: session, deckState: nil)

        let backpackItems = service.getBackpackItems(session: session)
        let error = try await service.moveBackpackToActive(item: backpackItems[0], session: session)

        #expect(error == nil, "Should succeed")
        #expect(service.getBackpackCount(session: session) == 0)
        #expect(service.getActiveCount(session: session) == 1)

        let activeItems = service.getActiveItems(session: session)
        #expect(activeItems[0].cardInstance?.id == instance.id)
        #expect(activeItems[0].isEquipped == true)
    }

    @Test func testMoveBackpackToActiveFailsWhenActiveFull() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        // Fill active
        for i in 0..<2 {
            let instance = createTestWeaponInstance(context: context, name: "Active \(i)")
            _ = try await service.addToActive(instance: instance, session: session, deckState: nil)
        }

        // Add to backpack
        let backpackInstance = createTestWeaponInstance(context: context, name: "Backpack Weapon")
        _ = try await service.addToBackpack(instance: backpackInstance, session: session, deckState: nil)

        let backpackItems = service.getBackpackItems(session: session)
        let error = try await service.moveBackpackToActive(item: backpackItems[0], session: session)

        #expect(error != nil, "Should fail with full active")
        #expect(error?.contains("Active slots full") == true)
    }

    @Test func testMoveRecordsEvent() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let instance = createTestWeaponInstance(context: context)
        _ = try await service.addToActive(instance: instance, session: session, deckState: nil)

        let activeItems = service.getActiveItems(session: session)
        _ = try await service.moveActiveToBackpack(item: activeItems[0], session: session)

        let history = service.getHistory(for: session)
        let moveEvent = history.first { $0.eventType == "move" }

        #expect(moveEvent != nil)
        #expect(moveEvent?.fromSlotType == "active")
        #expect(moveEvent?.slotType == "backpack")
    }

    // MARK: - Replacement Flow Tests

    @Test func testReplaceWeapon() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let oldInstance = createTestWeaponInstance(context: context, name: "Old Weapon")
        _ = try await service.addToActive(instance: oldInstance, session: session, deckState: nil)

        let activeItems = service.getActiveItems(session: session)
        let oldSlotIndex = activeItems[0].slotIndex

        let newInstance = createTestWeaponInstance(context: context, name: "New Weapon")
        try await service.replaceWeapon(
            old: activeItems[0],
            new: newInstance,
            session: session,
            discardOldToDeck: false,
            deckState: nil
        )

        let newActiveItems = service.getActiveItems(session: session)
        #expect(newActiveItems.count == 1)
        #expect(newActiveItems[0].cardInstance?.id == newInstance.id)
        #expect(newActiveItems[0].slotIndex == oldSlotIndex, "Should keep same slot")
    }

    @Test func testReplaceWeaponRecordsEvent() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let oldInstance = createTestWeaponInstance(context: context, name: "Old")
        _ = try await service.addToActive(instance: oldInstance, session: session, deckState: nil)

        let items = service.getActiveItems(session: session)
        let newInstance = createTestWeaponInstance(context: context, name: "New")

        try await service.replaceWeapon(
            old: items[0],
            new: newInstance,
            session: session,
            discardOldToDeck: false,
            deckState: nil
        )

        let history = service.getHistory(for: session)
        let replaceEvent = history.first { $0.eventType == "replace" }

        #expect(replaceEvent != nil)
        #expect(replaceEvent?.cardInstance?.id == newInstance.id)
    }

    // MARK: - History Tracking Tests

    @Test func testGetHistoryForSession() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let instance1 = createTestWeaponInstance(context: context, name: "Weapon 1")
        let instance2 = createTestWeaponInstance(context: context, name: "Weapon 2")

        _ = try await service.addToActive(instance: instance1, session: session, deckState: nil)
        _ = try await service.addToActive(instance: instance2, session: session, deckState: nil)

        let history = service.getHistory(for: session)

        #expect(history.count == 2)
        #expect(history.allSatisfy { $0.eventType == "add" })
    }

    @Test func testGetHistoryForSpecificWeapon() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        let instance1 = createTestWeaponInstance(context: context, name: "Weapon 1")
        let instance2 = createTestWeaponInstance(context: context, name: "Weapon 2")

        _ = try await service.addToActive(instance: instance1, session: session, deckState: nil)
        _ = try await service.addToActive(instance: instance2, session: session, deckState: nil)

        let history = service.getHistory(for: instance1, in: session)

        #expect(history.count == 1)
        #expect(history[0].cardInstance?.id == instance1.id)
    }

    // MARK: - Modifiers Support Tests

    @Test func testAllInventoryActiveModifier() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        session.allInventoryActive = true

        #expect(service.isAllInventoryActive(session: session))

        // Add weapons to both active and backpack
        let active = createTestWeaponInstance(context: context, name: "Active")
        let backpack = createTestWeaponInstance(context: context, name: "Backpack")

        _ = try await service.addToActive(instance: active, session: session, deckState: nil)
        _ = try await service.addToBackpack(instance: backpack, session: session, deckState: nil)

        let effectiveActive = service.getEffectiveActiveWeapons(session: session)

        #expect(effectiveActive.count == 2, "Both should count as active")
    }

    @Test func testEffectiveActiveWeaponsWithoutModifier() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        session.allInventoryActive = false

        let active = createTestWeaponInstance(context: context, name: "Active")
        let backpack = createTestWeaponInstance(context: context, name: "Backpack")

        _ = try await service.addToActive(instance: active, session: session, deckState: nil)
        _ = try await service.addToBackpack(instance: backpack, session: session, deckState: nil)

        let effectiveActive = service.getEffectiveActiveWeapons(session: session)

        #expect(effectiveActive.count == 1, "Only active slot should count")
    }

    // MARK: - Utility Methods Tests

    @Test func testHasInventory() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        #expect(!service.hasInventory(session: session))

        let instance = createTestWeaponInstance(context: context)
        _ = try await service.addToActive(instance: instance, session: session, deckState: nil)

        #expect(service.hasInventory(session: session))
    }

    @Test func testGetTotalCount() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        for i in 0..<2 {
            let instance = createTestWeaponInstance(context: context, name: "Active \(i)")
            _ = try await service.addToActive(instance: instance, session: session, deckState: nil)
        }

        for i in 0..<3 {
            let instance = createTestWeaponInstance(context: context, name: "Backpack \(i)")
            _ = try await service.addToBackpack(instance: instance, session: session, deckState: nil)
        }

        #expect(service.getTotalCount(session: session) == 5)
    }

    @Test func testSlotIndexing() async throws {
        let container = createTestContainer()
        let context = ModelContext(container)
        let (service, _) = createTestServices(container: container)
        let session = createTestSession(context: context)

        // Add multiple weapons
        for i in 0..<2 {
            let instance = createTestWeaponInstance(context: context, name: "Active \(i)")
            _ = try await service.addToActive(instance: instance, session: session, deckState: nil)
        }

        let activeItems = service.getActiveItems(session: session)

        // Check that indices are 0 and 1
        let indices = Set(activeItems.map { $0.slotIndex })
        #expect(indices.contains(0))
        #expect(indices.contains(1))
        #expect(indices.count == 2, "Should have unique indices")
    }
}
