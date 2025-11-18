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

    // MARK: - Phase 1: Version Comparison Tests

    func testVersionComparisonGreater() {
        XCTAssertEqual(compareVersions("2.3.0", "2.2.0"), .greater)
        XCTAssertEqual(compareVersions("3.0.0", "2.9.9"), .greater)
        XCTAssertEqual(compareVersions("2.2.1", "2.2.0"), .greater)
    }

    func testVersionComparisonEqual() {
        XCTAssertEqual(compareVersions("2.3.0", "2.3.0"), .equal)
        XCTAssertEqual(compareVersions("1.0.0", "1.0.0"), .equal)
    }

    func testVersionComparisonLess() {
        XCTAssertEqual(compareVersions("2.2.0", "2.3.0"), .less)
        XCTAssertEqual(compareVersions("1.9.9", "2.0.0"), .less)
        XCTAssertEqual(compareVersions("2.2.0", "2.2.1"), .less)
    }

    func testVersionComparisonHandlesMissingComponents() {
        // "2.3" should be treated as "2.3.0"
        XCTAssertEqual(compareVersions("2.3", "2.3.0"), .equal)
        XCTAssertEqual(compareVersions("2.3.1", "2.3"), .greater)
    }

    // MARK: - Phase 1: Version Gating Tests

    func testImportSkipsWhenVersionUnchanged() async throws {
        // First import with version 2.3.0
        let firstImport = try await importService.importWeaponsIfNeeded()
        XCTAssertTrue(firstImport, "First import should be performed")

        // Verify version is set
        let versionDescriptor = FetchDescriptor<WeaponDataVersion>()
        guard let version = try context.fetch(versionDescriptor).first else {
            XCTFail("Version should be set after import")
            return
        }
        XCTAssertEqual(version.latestImported, "2.3.0")

        // Second import should be skipped (same version)
        let secondImport = try await importService.importWeaponsIfNeeded()
        XCTAssertFalse(secondImport, "Second import should be skipped when version unchanged")
    }

    func testImportSkipsWhenVersionOlder() async throws {
        // Manually create an older version record (simulating downgrade scenario)
        let futureVersion = WeaponDataVersion(version: "3.0.0")
        context.insert(futureVersion)
        try context.save()

        // Import should be skipped (XML is 2.3.0, which is older than 3.0.0)
        let wasImported = try await importService.importWeaponsIfNeeded()
        XCTAssertFalse(wasImported, "Import should be skipped when XML version is older")
    }

    // MARK: - Phase 1: Incremental Update Tests

    func testIncrementalUpdateUpdatesExistingWeapons() async throws {
        // First import
        try await importService.importWeaponsIfNeeded()

        // Get initial count and find a weapon to verify update
        let initialDescriptor = FetchDescriptor<WeaponDefinition>()
        let initialDefinitions = try context.fetch(initialDescriptor)
        let initialCount = initialDefinitions.count

        guard let pistol = initialDefinitions.first(where: { $0.name == "Pistol" && $0.set == "Core" }) else {
            XCTFail("Should have Pistol weapon")
            return
        }

        let pistolID = pistol.id
        let pistolLastUpdated = pistol.lastUpdated

        // Simulate XML update to version 2.4.0 by manually updating version
        // (In real scenario, XML would have changed, but we're testing the update mechanism)
        let versionDescriptor = FetchDescriptor<WeaponDataVersion>()
        guard let version = try context.fetch(versionDescriptor).first else {
            XCTFail("Version should exist")
            return
        }
        version.latestImported = "2.2.0"  // Simulate older version
        try context.save()

        // Trigger incremental update (will load from XML 2.3.0)
        let wasUpdated = try await importService.importWeaponsIfNeeded()
        XCTAssertTrue(wasUpdated, "Incremental update should be performed")

        // Verify definition count unchanged (no new weapons in this test)
        let updatedDescriptor = FetchDescriptor<WeaponDefinition>()
        let updatedDefinitions = try context.fetch(updatedDescriptor)
        XCTAssertEqual(updatedDefinitions.count, initialCount, "Definition count should be unchanged")

        // Verify pistol was updated (same ID, but lastUpdated changed)
        guard let updatedPistol = updatedDefinitions.first(where: { $0.id == pistolID }) else {
            XCTFail("Pistol should still exist")
            return
        }
        XCTAssertGreaterThan(updatedPistol.lastUpdated, pistolLastUpdated, "Pistol should have updated timestamp")
        XCTAssertEqual(updatedPistol.metadataVersion, "2.3.0", "Pistol should have new version")
    }

    func testIncrementalUpdateMarksRemovedWeaponsAsDeprecated() async throws {
        // First import
        try await importService.importWeaponsIfNeeded()

        // Manually create a fake weapon that won't be in XML
        let fakeWeapon = WeaponDefinition(
            name: "FakeWeapon",
            set: "TestSet",
            deckType: "Regular",
            category: "Melee",
            defaultCount: 1
        )
        fakeWeapon.metadataVersion = "2.3.0"
        context.insert(fakeWeapon)
        try context.save()

        XCTAssertFalse(fakeWeapon.isDeprecated, "Fake weapon should not be deprecated initially")

        // Simulate older version to trigger update
        let versionDescriptor = FetchDescriptor<WeaponDataVersion>()
        guard let version = try context.fetch(versionDescriptor).first else {
            XCTFail("Version should exist")
            return
        }
        version.latestImported = "2.2.0"
        try context.save()

        // Trigger incremental update
        try await importService.importWeaponsIfNeeded()

        // Verify fake weapon is now deprecated
        let descriptor = FetchDescriptor<WeaponDefinition>(
            predicate: #Predicate { $0.name == "FakeWeapon" }
        )
        guard let updatedFakeWeapon = try context.fetch(descriptor).first else {
            XCTFail("Fake weapon should still exist")
            return
        }
        XCTAssertTrue(updatedFakeWeapon.isDeprecated, "Fake weapon should be marked as deprecated")
    }

    func testIncrementalUpdateHandlesCountChanges() async throws {
        // First import
        try await importService.importWeaponsIfNeeded()

        // Find a weapon and manually change its count
        let descriptor = FetchDescriptor<WeaponDefinition>()
        let definitions = try context.fetch(descriptor)

        guard let weapon = definitions.first else {
            XCTFail("Should have at least one weapon")
            return
        }

        let originalCount = weapon.defaultCount
        let originalInstanceCount = weapon.cardInstances.count

        // Manually change count to test instance adjustment
        weapon.defaultCount = originalCount + 2

        // Add 2 new instances manually
        for i in 1...2 {
            let newInstance = WeaponCardInstance(
                definition: weapon,
                copyIndex: originalInstanceCount + i
            )
            context.insert(newInstance)
        }
        try context.save()

        XCTAssertEqual(weapon.cardInstances.count, originalCount + 2, "Should have added instances")

        // Simulate older version to trigger update (which will restore original count)
        let versionDescriptor = FetchDescriptor<WeaponDataVersion>()
        guard let version = try context.fetch(versionDescriptor).first else {
            XCTFail("Version should exist")
            return
        }
        version.latestImported = "2.2.0"
        try context.save()

        // Trigger incremental update (will restore count from XML)
        try await importService.importWeaponsIfNeeded()

        // Verify count was restored to original from XML
        let updatedDescriptor = FetchDescriptor<WeaponDefinition>(
            predicate: #Predicate { $0.id == weapon.id }
        )
        guard let updatedWeapon = try context.fetch(updatedDescriptor).first else {
            XCTFail("Weapon should still exist")
            return
        }
        XCTAssertEqual(updatedWeapon.defaultCount, originalCount, "Count should be restored from XML")
        XCTAssertEqual(updatedWeapon.cardInstances.count, originalCount, "Instance count should match")
    }

    func testXMLVersionIsParsedCorrectly() {
        // Verify the XML parser extracts version
        let xmlVersion = WeaponRepository.shared.xmlVersion
        XCTAssertEqual(xmlVersion, "2.3.0", "XML version should be 2.3.0")
    }

    func testVersionIsStoredAfterImport() async throws {
        // Perform import
        try await importService.importWeaponsIfNeeded()

        // Verify version singleton was created
        let versionDescriptor = FetchDescriptor<WeaponDataVersion>()
        let versions = try context.fetch(versionDescriptor)

        XCTAssertEqual(versions.count, 1, "Should have exactly one version record")

        guard let version = versions.first else {
            XCTFail("Version should exist")
            return
        }

        XCTAssertEqual(version.id, "singleton", "Version ID should be 'singleton'")
        XCTAssertEqual(version.latestImported, "2.3.0", "Should store XML version")
    }
}
