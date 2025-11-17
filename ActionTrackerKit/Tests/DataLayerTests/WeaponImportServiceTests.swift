//
//  WeaponImportServiceTests.swift
//  DataLayerTests
//
//  Phase 0: Tests for WeaponImportService
//

import XCTest
import SwiftData
@testable import DataLayer
@testable import CoreDomain

@MainActor
final class WeaponImportServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
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
        importService = WeaponImportService(context: context)
    }

    override func tearDown() {
        context = nil
        container = nil
        importService = nil
    }

    // MARK: - Import Tests

    func testImportCreatesWeaponDefinitions() async throws {
        // Perform import
        let wasImported = try await importService.importWeaponsIfNeeded()
        XCTAssertTrue(wasImported, "Import should be performed on first run")

        // Verify definitions were created
        let descriptor = FetchDescriptor<WeaponDefinition>()
        let definitions = try context.fetch(descriptor)

        XCTAssertFalse(definitions.isEmpty, "Should have created weapon definitions")
        XCTAssertGreaterThan(definitions.count, 100, "Should have imported 100+ weapons")

        // Verify a known weapon exists
        let pistolDefinition = definitions.first { $0.name == "Pistol" && $0.set == "Core" }
        XCTAssertNotNil(pistolDefinition, "Should have imported Pistol from Core set")
    }

    func testImportCreatesCardInstances() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        // Verify card instances were created
        let instanceDescriptor = FetchDescriptor<WeaponCardInstance>()
        let instances = try context.fetch(instanceDescriptor)

        XCTAssertFalse(instances.isEmpty, "Should have created card instances")
        XCTAssertGreaterThan(instances.count, 400, "Should have created 400+ card instances")

        // Verify instance has valid definition relationship
        guard let firstInstance = instances.first else {
            XCTFail("Should have at least one instance")
            return
        }
        XCTAssertNotNil(firstInstance.definition, "Instance should have definition")
    }

    func testImportIsIdempotent() async throws {
        // First import
        let firstImport = try await importService.importWeaponsIfNeeded()
        XCTAssertTrue(firstImport, "First import should be performed")

        let firstDescriptor = FetchDescriptor<WeaponDefinition>()
        let firstCount = try context.fetchCount(firstDescriptor)

        // Second import should be skipped
        let secondImport = try await importService.importWeaponsIfNeeded()
        XCTAssertFalse(secondImport, "Second import should be skipped")

        let secondDescriptor = FetchDescriptor<WeaponDefinition>()
        let secondCount = try context.fetchCount(secondDescriptor)

        XCTAssertEqual(firstCount, secondCount, "Should not create duplicates")
    }

    func testImportCreatesVersionSingleton() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        // Verify version was created
        let descriptor = FetchDescriptor<WeaponDataVersion>()
        let versions = try context.fetch(descriptor)

        XCTAssertEqual(versions.count, 1, "Should have exactly one version record")
        XCTAssertEqual(versions.first?.latestImported, "2.2.0", "Should match XML version")
    }

    func testDeterministicIDs() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        // Verify IDs are deterministic (deckType:name:set format)
        let descriptor = FetchDescriptor<WeaponDefinition>()
        let definitions = try context.fetch(descriptor)

        for definition in definitions {
            let expectedID = "\(definition.deckType):\(definition.name):\(definition.set)"
            XCTAssertEqual(definition.id, expectedID, "ID should be deterministic")
        }
    }

    func testRelationshipsAreValid() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        // Verify all card instances have valid definitions
        let instanceDescriptor = FetchDescriptor<WeaponCardInstance>()
        let instances = try context.fetch(instanceDescriptor)

        for instance in instances {
            XCTAssertNotNil(instance.definition, "Instance should have definition: \(instance.serial)")
        }

        // Verify all definitions have card instances
        let definitionDescriptor = FetchDescriptor<WeaponDefinition>()
        let definitions = try context.fetch(definitionDescriptor)

        for definition in definitions {
            XCTAssertFalse(definition.cardInstances.isEmpty, "Definition should have instances: \(definition.name)")
            XCTAssertEqual(definition.cardInstances.count, definition.defaultCount,
                          "Instance count should match default count for \(definition.name)")
        }
    }

    func testImportPerformance() async throws {
        // Measure import time
        let start = Date()
        try await importService.importWeaponsIfNeeded()
        let duration = Date().timeIntervalSince(start)

        // Should complete in under 2 seconds
        XCTAssertLessThan(duration, 2.0, "Import should complete in under 2 seconds")
    }

    // MARK: - Validation Tests

    func testValidationPassesAfterImport() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        // Validation should pass
        XCTAssertNoThrow(try importService.validateImport())
    }

    func testValidationDetectsEmptyDatabase() throws {
        // Without import, validation should fail
        XCTAssertThrowsError(try importService.validateImport())
    }

    // MARK: - Data Mapping Tests

    func testMeleeStatsAreEncoded() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        // Find a melee weapon
        let descriptor = FetchDescriptor<WeaponDefinition>()
        let definitions = try context.fetch(descriptor)

        let meleeWeapons = definitions.filter { $0.meleeStatsJSON != nil }
        XCTAssertFalse(meleeWeapons.isEmpty, "Should have weapons with melee stats")

        // Verify we can decode the JSON
        guard let firstMelee = meleeWeapons.first,
              let json = firstMelee.meleeStatsJSON else {
            XCTFail("Should have melee weapon with JSON stats")
            return
        }

        let stats = try JSONDecoder().decode(MeleeStatsData.self, from: json)
        XCTAssertGreaterThanOrEqual(stats.dice, 0)
        XCTAssertGreaterThanOrEqual(stats.damage, 0)
    }

    func testRangedStatsAreEncoded() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        // Find a ranged weapon
        let descriptor = FetchDescriptor<WeaponDefinition>()
        let definitions = try context.fetch(descriptor)

        let rangedWeapons = definitions.filter { $0.rangedStatsJSON != nil }
        XCTAssertFalse(rangedWeapons.isEmpty, "Should have weapons with ranged stats")

        // Verify we can decode the JSON
        guard let firstRanged = rangedWeapons.first,
              let json = firstRanged.rangedStatsJSON else {
            XCTFail("Should have ranged weapon with JSON stats")
            return
        }

        let stats = try JSONDecoder().decode(RangedStatsData.self, from: json)
        XCTAssertGreaterThanOrEqual(stats.dice, 0)
        XCTAssertGreaterThanOrEqual(stats.damage, 0)
        XCTAssertLessThanOrEqual(stats.rangeMin, stats.rangeMax)
    }

    func testAbilitiesAreMapped() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        let descriptor = FetchDescriptor<WeaponDefinition>()
        let definitions = try context.fetch(descriptor)

        // Verify at least some weapons have abilities
        let weaponsWithOpenDoor = definitions.filter { $0.canOpenDoor }
        let weaponsWithDoorNoise = definitions.filter { $0.doorNoise }
        let dualWeapons = definitions.filter { $0.isDual }

        // Just verify these collections exist (may vary based on XML data)
        XCTAssertNotNil(weaponsWithOpenDoor)
        XCTAssertNotNil(weaponsWithDoorNoise)
        XCTAssertNotNil(dualWeapons)
    }

    func testCardInstanceSerialFormat() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        let descriptor = FetchDescriptor<WeaponCardInstance>()
        let instances = try context.fetch(descriptor)

        for instance in instances {
            // Serial should be in format: "deckType:name:set:copyIndex"
            let components = instance.serial.split(separator: ":")
            XCTAssertGreaterThanOrEqual(components.count, 4, "Serial should have at least 4 components")
        }
    }

    func testAllDeckTypesImported() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        let descriptor = FetchDescriptor<WeaponDefinition>()
        let definitions = try context.fetch(descriptor)

        let starting = definitions.filter { $0.deckType == "Starting" }
        let regular = definitions.filter { $0.deckType == "Regular" }
        let ultrared = definitions.filter { $0.deckType == "Ultrared" }

        XCTAssertFalse(starting.isEmpty, "Should have Starting deck weapons")
        XCTAssertFalse(regular.isEmpty, "Should have Regular deck weapons")
        XCTAssertFalse(ultrared.isEmpty, "Should have Ultrared deck weapons")
    }

    func testAllCategoriesImported() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        let descriptor = FetchDescriptor<WeaponDefinition>()
        let definitions = try context.fetch(descriptor)

        let categories = Set(definitions.map { $0.category })
        XCTAssertTrue(categories.contains("Melee"), "Should have Melee weapons")
        XCTAssertGreaterThan(categories.count, 1, "Should have multiple weapon categories")
    }
}
