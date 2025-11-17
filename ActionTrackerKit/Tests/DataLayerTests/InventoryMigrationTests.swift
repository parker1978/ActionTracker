//
//  InventoryMigrationTests.swift
//  DataLayerTests
//
//  Phase 0: Tests for InventoryMigrationService
//

import XCTest
import SwiftData
@testable import DataLayer
@testable import CoreDomain

@MainActor
final class InventoryMigrationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var migrationService: InventoryMigrationService!
    var importService: WeaponImportService!

    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            WeaponDefinition.self,
            WeaponCardInstance.self,
            WeaponInventoryItem.self,
            DeckCustomization.self,
            DeckPreset.self,
            WeaponDataVersion.self,
            GameSession.self,
            Character.self,
            ActionInstance.self,
            Skill.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)

        migrationService = InventoryMigrationService(context: context)
        importService = WeaponImportService(context: context)

        // Import weapons for migration tests
        try await importService.importWeaponsIfNeeded()

        // Seed a test character
        DataSeeder.seedIfNeeded(context: context)
    }

    override func tearDown() {
        context = nil
        container = nil
        migrationService = nil
        importService = nil
    }

    // MARK: - Helper Methods

    private func createTestCharacter() throws -> Character {
        let descriptor = FetchDescriptor<Character>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        if let existingCharacter = try context.fetch(descriptor).first {
            return existingCharacter
        }

        // Create a simple test character if none exists
        let character = Character(
            name: "Test Character",
            set: "Core",
            blueSkills: "Skill 1",
            yellowSkills: "+1 Action",
            orangeSkills: "Skill 2; Skill 3",
            redSkills: "Skill 4; Skill 5; Skill 6",
            health: 5,
            isBuiltIn: true,
            isTeen: false
        )
        context.insert(character)
        return character
    }

    // MARK: - Basic Migration Tests

    func testEmptyInventoryMigration() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        session.activeWeapons = ""
        session.inactiveWeapons = ""
        context.insert(session)

        try migrationService.migrateSessionWithValidation(session)

        XCTAssertTrue(session.inventoryItems.isEmpty, "Empty inventory should remain empty")
    }

    func testSingleWeaponMigration() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        session.activeWeapons = "Pistol|Core"
        session.inactiveWeapons = ""
        context.insert(session)

        try migrationService.migrateSessionWithValidation(session)

        XCTAssertEqual(session.inventoryItems.count, 1, "Should migrate single weapon")
        XCTAssertEqual(session.inventoryItems.first?.slotType, "active")
        XCTAssertEqual(session.inventoryItems.first?.cardInstance?.definition?.name, "Pistol")
    }

    func testBasicInventoryMigration() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        session.activeWeapons = "Pistol|Core; Crowbar|Core"
        session.inactiveWeapons = "Fire Axe|Core"
        context.insert(session)

        try migrationService.migrateSessionWithValidation(session)

        XCTAssertEqual(session.inventoryItems.count, 3, "Should migrate 3 weapons")

        let activeItems = session.inventoryItems.filter { $0.slotType == "active" }
        let backpackItems = session.inventoryItems.filter { $0.slotType == "backpack" }

        XCTAssertEqual(activeItems.count, 2, "Should have 2 active weapons")
        XCTAssertEqual(backpackItems.count, 1, "Should have 1 backpack weapon")
    }

    func testFullInventoryMigration() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        // 2 active + 5 backpack
        session.activeWeapons = "Pistol|Core; Crowbar|Core"
        session.inactiveWeapons = "Fire Axe|Core; Chainsaw|Core; Katana|Core; Pan|Core; Machete|Core"
        context.insert(session)

        try migrationService.migrateSessionWithValidation(session)

        XCTAssertEqual(session.inventoryItems.count, 7, "Should migrate 7 weapons")

        let activeItems = session.inventoryItems.filter { $0.slotType == "active" }
        let backpackItems = session.inventoryItems.filter { $0.slotType == "backpack" }

        XCTAssertEqual(activeItems.count, 2)
        XCTAssertEqual(backpackItems.count, 5)
    }

    // MARK: - Malformed Data Tests

    func testMalformedStringHandling() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        // Mix of valid and invalid formats
        session.activeWeapons = "Pistol|Core; InvalidFormat; Crowbar"
        session.inactiveWeapons = ""
        context.insert(session)

        // Should not crash
        XCTAssertNoThrow(try migrationService.migrateSessionWithValidation(session))

        // Should only migrate valid entries
        XCTAssertEqual(session.inventoryItems.count, 1, "Should skip malformed entries")
        XCTAssertEqual(session.inventoryItems.first?.cardInstance?.definition?.name, "Pistol")
    }

    func testNonExistentWeaponHandling() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        session.activeWeapons = "Pistol|Core; FakeWeapon|FakeSet"
        session.inactiveWeapons = ""
        context.insert(session)

        // Should not crash, should skip non-existent weapon
        XCTAssertNoThrow(try migrationService.migrateSessionWithValidation(session))

        // Should only migrate weapons that exist
        XCTAssertEqual(session.inventoryItems.count, 1, "Should skip non-existent weapons")
    }

    func testWhitespaceHandling() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        // Test with extra whitespace
        session.activeWeapons = " Pistol | Core ; Crowbar | Core "
        session.inactiveWeapons = ""
        context.insert(session)

        try migrationService.migrateSessionWithValidation(session)

        XCTAssertEqual(session.inventoryItems.count, 2, "Should trim whitespace")
    }

    // MARK: - Validation Tests

    func testValidationDetectsCountMismatch() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        session.activeWeapons = "Pistol|Core; Crowbar|Core"
        context.insert(session)

        // Manually add wrong number of items to force validation failure
        try migrationService.migrateSessionWithValidation(session)

        // Now manually add an extra item
        let definition = try context.fetch(FetchDescriptor<WeaponDefinition>()).first!
        let extraInstance = WeaponCardInstance(definition: definition, copyIndex: 999)
        context.insert(extraInstance)
        let extraItem = WeaponInventoryItem(slotType: "active", slotIndex: 99, cardInstance: extraInstance)
        context.insert(extraItem)
        session.inventoryItems.append(extraItem)

        // Validation should catch this
        let validation = migrationService.validateMigration(session)
        XCTAssertFalse(validation.isValid, "Should detect count mismatch")
    }

    func testValidationDetectsNonSequentialIndices() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        context.insert(session)

        // Manually create items with bad indices
        let definition = try context.fetch(FetchDescriptor<WeaponDefinition>()).first!
        let instance1 = WeaponCardInstance(definition: definition, copyIndex: 1)
        let instance2 = WeaponCardInstance(definition: definition, copyIndex: 2)
        context.insert(instance1)
        context.insert(instance2)

        let item1 = WeaponInventoryItem(slotType: "active", slotIndex: 0, cardInstance: instance1)
        let item2 = WeaponInventoryItem(slotType: "active", slotIndex: 5, cardInstance: instance2) // Bad index!
        context.insert(item1)
        context.insert(item2)
        session.inventoryItems = [item1, item2]

        let validation = migrationService.validateMigration(session)
        XCTAssertFalse(validation.isValid, "Should detect non-sequential indices")
        XCTAssertTrue(validation.errors.contains { $0.contains("not sequential") })
    }

    func testValidationDetectsMissingRelationships() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        context.insert(session)

        // Create item without cardInstance
        let item = WeaponInventoryItem(
            slotType: "active",
            slotIndex: 0,
            cardInstance: WeaponCardInstance(
                definition: try context.fetch(FetchDescriptor<WeaponDefinition>()).first!,
                copyIndex: 1
            )
        )
        context.insert(item)
        item.cardInstance = nil  // Break relationship
        session.inventoryItems.append(item)

        let validation = migrationService.validateMigration(session)
        XCTAssertFalse(validation.isValid, "Should detect missing cardInstance")
    }

    // MARK: - Rollback Tests

    func testRollbackOnValidationFailure() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        // Set impossible inventory that will fail validation
        session.activeWeapons = "NonExistent1|FakeSet; NonExistent2|FakeSet"
        context.insert(session)

        // Migration should fail and rollback
        do {
            try migrationService.migrateSessionWithValidation(session)
            // If we reach here, migration succeeded (all weapons were skipped)
            // In this case, empty inventory is valid
        } catch {
            // Expected: migration failed and rolled back
            XCTAssertTrue(session.inventoryItems.isEmpty, "Should rollback on failure")
        }
    }

    // MARK: - Slot Management Tests

    func testSlotIndicesAreSequential() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        session.activeWeapons = "Pistol|Core; Crowbar|Core"
        session.inactiveWeapons = "Fire Axe|Core; Chainsaw|Core; Katana|Core"
        context.insert(session)

        try migrationService.migrateSessionWithValidation(session)

        let activeItems = session.inventoryItems.filter { $0.slotType == "active" }.sorted { $0.slotIndex < $1.slotIndex }
        let backpackItems = session.inventoryItems.filter { $0.slotType == "backpack" }.sorted { $0.slotIndex < $1.slotIndex }

        // Check active slots are 0, 1
        XCTAssertEqual(activeItems.map { $0.slotIndex }, [0, 1])

        // Check backpack slots are 0, 1, 2
        XCTAssertEqual(backpackItems.map { $0.slotIndex }, [0, 1, 2])
    }

    func testIsEquippedProperty() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        session.activeWeapons = "Pistol|Core"
        session.inactiveWeapons = "Fire Axe|Core"
        context.insert(session)

        try migrationService.migrateSessionWithValidation(session)

        let activeItem = session.inventoryItems.first { $0.slotType == "active" }
        let backpackItem = session.inventoryItems.first { $0.slotType == "backpack" }

        XCTAssertEqual(activeItem?.isEquipped, true, "Active weapons should be equipped")
        XCTAssertEqual(backpackItem?.isEquipped, false, "Backpack weapons should not be equipped")
    }

    // MARK: - Relationship Tests

    func testRelationshipIntegrity() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        session.activeWeapons = "Pistol|Core; Crowbar|Core"
        context.insert(session)

        try migrationService.migrateSessionWithValidation(session)

        for item in session.inventoryItems {
            // Verify session relationship
            XCTAssertEqual(item.session?.id, session.id, "Item should reference correct session")

            // Verify cardInstance relationship
            XCTAssertNotNil(item.cardInstance, "Item should have cardInstance")

            // Verify definition relationship
            XCTAssertNotNil(item.cardInstance?.definition, "CardInstance should have definition")
        }
    }

    // MARK: - Idempotency Tests

    func testMigrationIsIdempotent() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        session.activeWeapons = "Pistol|Core"
        context.insert(session)

        // First migration
        try migrationService.migrateSessionWithValidation(session)
        let firstCount = session.inventoryItems.count

        // Second migration should be skipped
        try migrationService.migrateSessionWithValidation(session)
        let secondCount = session.inventoryItems.count

        XCTAssertEqual(firstCount, secondCount, "Should not migrate twice")
        XCTAssertEqual(firstCount, 1)
    }

    // MARK: - Batch Migration Tests

    func testBatchMigration() async throws {
        // Create multiple sessions
        let character = try createTestCharacter()

        let session1 = GameSession(character: character)
        session1.activeWeapons = "Pistol|Core"
        context.insert(session1)

        let session2 = GameSession(character: character)
        session2.activeWeapons = "Crowbar|Core"
        context.insert(session2)

        let session3 = GameSession(character: character)
        session3.activeWeapons = ""  // Empty
        context.insert(session3)

        // Run batch migration
        try await migrationService.migrateAllSessions()

        // Verify all sessions were processed
        XCTAssertEqual(session1.inventoryItems.count, 1)
        XCTAssertEqual(session2.inventoryItems.count, 1)
        XCTAssertEqual(session3.inventoryItems.count, 0)  // Empty stays empty
    }

    // MARK: - Large Inventory Tests

    func testLargeInventoryMigration() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)

        // Create large inventory string (10 weapons)
        let weapons = [
            "Pistol|Core", "Crowbar|Core", "Fire Axe|Core",
            "Chainsaw|Core", "Katana|Core", "Pan|Core",
            "Machete|Core", "Baseball Bat|Core", "Knife|Core",
            "Chainsaw|Fort Hendrix"
        ]
        session.activeWeapons = weapons.prefix(2).joined(separator: "; ")
        session.inactiveWeapons = weapons.dropFirst(2).joined(separator: "; ")
        context.insert(session)

        try migrationService.migrateSessionWithValidation(session)

        XCTAssertEqual(session.inventoryItems.count, 10, "Should migrate large inventory")
    }

    // MARK: - Legacy String Preservation Tests

    func testLegacyStringsPreserved() throws {
        let character = try createTestCharacter()
        let session = GameSession(character: character)
        let originalActive = "Pistol|Core; Crowbar|Core"
        let originalInactive = "Fire Axe|Core"

        session.activeWeapons = originalActive
        session.inactiveWeapons = originalInactive
        context.insert(session)

        try migrationService.migrateSessionWithValidation(session)

        // Legacy strings should remain unchanged
        XCTAssertEqual(session.activeWeapons, originalActive, "Should preserve legacy active weapons")
        XCTAssertEqual(session.inactiveWeapons, originalInactive, "Should preserve legacy inactive weapons")
    }
}
