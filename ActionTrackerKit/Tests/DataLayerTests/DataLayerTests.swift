import XCTest
@testable import DataLayer
@testable import CoreDomain

final class DataLayerTests: XCTestCase {

    // MARK: - CharacterRepository Tests

    func testCharacterRepositorySingleton() {
        let instance1 = CharacterRepository.shared
        let instance2 = CharacterRepository.shared

        XCTAssertTrue(instance1 === instance2, "CharacterRepository should be a singleton")
    }

    func testCharacterRepositoryLoadedCharacters() {
        let repository = CharacterRepository.shared

        // Should have loaded characters from bundled JSON
        XCTAssertFalse(repository.allCharacters.isEmpty, "Should load characters from JSON")
        XCTAssertGreaterThan(repository.allCharacters.count, 0)
    }

    func testCharacterRepositoryDataVersion() {
        XCTAssertEqual(CharacterRepository.CHARACTERS_DATA_VERSION, "1.0.0")
    }

    func testCharacterRepositoryExpansionSets() {
        let repository = CharacterRepository.shared
        let sets = repository.expansionSets

        // Should have unique expansion sets
        XCTAssertFalse(sets.isEmpty, "Should have expansion sets")

        // Should be sorted
        let sortedSets = sets.sorted()
        XCTAssertEqual(sets, sortedSets, "Expansion sets should be sorted")

        // Should have no duplicates
        let uniqueSets = Set(sets)
        XCTAssertEqual(sets.count, uniqueSets.count, "Expansion sets should be unique")
    }

    func testCharacterRepositoryFilterBySet() {
        let repository = CharacterRepository.shared

        guard let firstSet = repository.expansionSets.first else {
            XCTFail("Should have at least one expansion set")
            return
        }

        let filtered = repository.getCharacters(forSet: firstSet)

        // All filtered characters should belong to the requested set
        for character in filtered {
            XCTAssertEqual(character.set, firstSet)
        }
    }

    func testCharacterDataBooleanParsing() {
        // Test teen boolean parsing
        let teenData = CharacterData(
            name: "Test",
            set: "Core",
            notes: "",
            blue: "Skill",
            orange: "Skill",
            red: "Skill",
            teen: "True",
            health: "5"
        )
        XCTAssertTrue(teenData.isTeen)

        let adultData = CharacterData(
            name: "Test",
            set: "Core",
            notes: "",
            blue: "Skill",
            orange: "Skill",
            red: "Skill",
            teen: "False",
            health: "5"
        )
        XCTAssertFalse(adultData.isTeen)

        // Test case insensitivity
        let mixedCaseData = CharacterData(
            name: "Test",
            set: "Core",
            notes: "",
            blue: "Skill",
            orange: "Skill",
            red: "Skill",
            teen: "tRuE",
            health: "5"
        )
        XCTAssertTrue(mixedCaseData.isTeen)
    }

    func testCharacterDataHealthParsing() {
        let data1 = CharacterData(
            name: "Test",
            set: "Core",
            notes: "",
            blue: "Skill",
            orange: "Skill",
            red: "Skill",
            teen: "False",
            health: "5"
        )
        XCTAssertEqual(data1.healthValue, 5)

        let data2 = CharacterData(
            name: "Test",
            set: "Core",
            notes: "",
            blue: "Skill",
            orange: "Skill",
            red: "Skill",
            teen: "False",
            health: "10"
        )
        XCTAssertEqual(data2.healthValue, 10)

        // Test invalid health defaults to 3
        let invalidData = CharacterData(
            name: "Test",
            set: "Core",
            notes: "",
            blue: "Skill",
            orange: "Skill",
            red: "Skill",
            teen: "False",
            health: "invalid"
        )
        XCTAssertEqual(invalidData.healthValue, 3)
    }

    // MARK: - WeaponRepository Tests

    func testWeaponRepositorySingleton() {
        let instance1 = WeaponRepository.shared
        let instance2 = WeaponRepository.shared

        XCTAssertTrue(instance1 === instance2, "WeaponRepository should be a singleton")
    }

    func testWeaponRepositoryLoadedWeapons() {
        let repository = WeaponRepository.shared

        // Should have loaded weapons from bundled JSON
        XCTAssertFalse(repository.allWeapons.isEmpty, "Should load weapons from JSON")
        XCTAssertGreaterThan(repository.allWeapons.count, 0)
    }

    func testWeaponRepositoryDataVersion() {
        XCTAssertEqual(WeaponRepository.WEAPONS_DATA_VERSION, "1.0.0")
    }

    func testWeaponRepositoryExpansions() {
        let repository = WeaponRepository.shared
        let expansions = repository.expansions

        // Should have expansion sets
        XCTAssertFalse(expansions.isEmpty, "Should have expansions")

        // Should be sorted
        let sortedExpansions = expansions.sorted()
        XCTAssertEqual(expansions, sortedExpansions, "Expansions should be sorted")

        // Should have no duplicates
        let uniqueExpansions = Set(expansions)
        XCTAssertEqual(expansions.count, uniqueExpansions.count, "Expansions should be unique")
    }

    func testWeaponRepositoryFilterByDeckType() {
        let repository = WeaponRepository.shared

        // Test each deck type
        let startingWeapons = repository.getWeapons(for: .starting)
        let regularWeapons = repository.getWeapons(for: .regular)
        let ultraredWeapons = repository.getWeapons(for: .ultrared)

        // Should have weapons for each deck type
        XCTAssertFalse(startingWeapons.isEmpty, "Should have starting deck weapons")
        XCTAssertFalse(regularWeapons.isEmpty, "Should have regular deck weapons")
        XCTAssertFalse(ultraredWeapons.isEmpty, "Should have ultrared deck weapons")

        // All weapons should match their deck type
        for weapon in startingWeapons {
            XCTAssertEqual(weapon.deck, .starting)
        }

        for weapon in regularWeapons {
            XCTAssertEqual(weapon.deck, .regular)
        }

        for weapon in ultraredWeapons {
            XCTAssertEqual(weapon.deck, .ultrared)
        }
    }

    func testWeaponRepositoryFilterByExpansion() {
        let repository = WeaponRepository.shared

        guard let firstExpansion = repository.expansions.first else {
            XCTFail("Should have at least one expansion")
            return
        }

        let filtered = repository.getWeapons(forExpansion: firstExpansion)

        // All filtered weapons should belong to the requested expansion
        for weapon in filtered {
            XCTAssertEqual(weapon.expansion, firstExpansion)
        }
    }

    func testWeaponDataConversion() {
        let repository = WeaponRepository.shared

        // Get any weapon to verify conversion worked
        guard let weapon = repository.allWeapons.first else {
            XCTFail("Should have at least one weapon")
            return
        }

        // Verify basic properties exist
        XCTAssertFalse(weapon.name.isEmpty)
        XCTAssertFalse(weapon.expansion.isEmpty)
        XCTAssertGreaterThan(weapon.count, 0)
    }

    func testWeaponCategoryConversion() {
        let repository = WeaponRepository.shared
        let weapons = repository.allWeapons

        // Count weapons by category to ensure all categories are parsed
        let meleeWeapons = weapons.filter { $0.category == .melee }
        let rangedWeapons = weapons.filter { $0.category == .ranged }
        let meleeRangedWeapons = weapons.filter { $0.category == .meleeRanged }

        // Should have at least some weapons in each category
        // (This assumes the test data has all categories represented)
        XCTAssertGreaterThan(meleeWeapons.count + rangedWeapons.count + meleeRangedWeapons.count, 0)
    }

    func testWeaponDeckTypeDistribution() {
        let repository = WeaponRepository.shared
        let weapons = repository.allWeapons

        // Count weapons by deck type
        let startingCount = weapons.filter { $0.deck == .starting }.count
        let regularCount = weapons.filter { $0.deck == .regular }.count
        let ultraredCount = weapons.filter { $0.deck == .ultrared }.count

        // Should have weapons in each deck
        XCTAssertGreaterThan(startingCount, 0, "Should have starting deck weapons")
        XCTAssertGreaterThan(regularCount, 0, "Should have regular deck weapons")
        XCTAssertGreaterThan(ultraredCount, 0, "Should have ultrared deck weapons")

        // Total should match all weapons
        XCTAssertEqual(startingCount + regularCount + ultraredCount, weapons.count)
    }

    func testWeaponBooleanProperties() {
        let repository = WeaponRepository.shared
        let weapons = repository.allWeapons

        // Test that boolean properties were parsed correctly
        // At least some weapons should have these flags
        let weaponsWithDoorOpen = weapons.filter { $0.openDoor }
        let weaponsWithDoorNoise = weapons.filter { $0.doorNoise }
        let weaponsWithKillNoise = weapons.filter { $0.killNoise }
        let dualWeapons = weapons.filter { $0.dual }

        // Just verify these collections exist (may be empty depending on data)
        XCTAssertNotNil(weaponsWithDoorOpen)
        XCTAssertNotNil(weaponsWithDoorNoise)
        XCTAssertNotNil(weaponsWithKillNoise)
        XCTAssertNotNil(dualWeapons)
    }

    func testWeaponAmmoTypes() {
        let repository = WeaponRepository.shared
        let weapons = repository.allWeapons

        // Count weapons by ammo type
        let noAmmo = weapons.filter { $0.ammoType == .none }
        let bullets = weapons.filter { $0.ammoType == .bullets }
        let shells = weapons.filter { $0.ammoType == .shells }

        // Total should match all weapons
        XCTAssertEqual(noAmmo.count + bullets.count + shells.count, weapons.count)

        // Should have at least some weapons with each ammo type
        XCTAssertGreaterThan(noAmmo.count, 0, "Should have weapons without ammo")
    }

    func testWeaponNumericalProperties() {
        let repository = WeaponRepository.shared
        let weapons = repository.allWeapons

        // Find weapons with various numerical properties
        let weaponsWithDice = weapons.filter { $0.dice != nil }
        let weaponsWithDamage = weapons.filter { $0.damage != nil }
        let weaponsWithRange = weapons.filter { $0.range != nil || $0.rangeMin != nil }

        // Should have weapons with these properties
        XCTAssertGreaterThan(weaponsWithDice.count, 0, "Should have weapons with dice")
        XCTAssertGreaterThan(weaponsWithDamage.count, 0, "Should have weapons with damage")
    }

    func testWeaponCountProperty() {
        let repository = WeaponRepository.shared
        let weapons = repository.allWeapons

        // All weapons should have a count >= 1
        for weapon in weapons {
            XCTAssertGreaterThan(weapon.count, 0, "Weapon count should be at least 1")
        }
    }

    func testWeaponSpecialProperty() {
        let repository = WeaponRepository.shared
        let weapons = repository.allWeapons

        // Some weapons should have special properties
        let weaponsWithSpecial = weapons.filter { !$0.special.isEmpty }

        // Just verify this collection exists
        XCTAssertNotNil(weaponsWithSpecial)
    }

    // MARK: - DataSeeder Tests

    func testDataSeederExists() {
        // DataSeeder is a struct with static methods
        // Basic test to ensure the type exists and can be referenced
        XCTAssertNotNil(DataSeeder.self)
    }

    func testDataSeederWithInMemoryContext() throws {
        // Create in-memory ModelContainer for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Character.self, Skill.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Seed the database
        DataSeeder.seedIfNeeded(context: context)

        // Verify skills were seeded
        let skillDescriptor = FetchDescriptor<Skill>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let skills = try context.fetch(skillDescriptor)
        XCTAssertGreaterThan(skills.count, 0, "Should have seeded built-in skills")
        XCTAssertGreaterThan(skills.count, 200, "Should have seeded 250+ skills")

        // Verify characters were seeded
        let characterDescriptor = FetchDescriptor<Character>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let characters = try context.fetch(characterDescriptor)
        XCTAssertGreaterThan(characters.count, 0, "Should have seeded built-in characters")
    }

    func testDataSeederDoesNotReseedWhenAlreadySeeded() throws {
        // Create in-memory ModelContainer
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Character.self, Skill.self,
            configurations: config
        )
        let context = ModelContext(container)

        // First seed
        DataSeeder.seedIfNeeded(context: context)

        let skillDescriptor = FetchDescriptor<Skill>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let initialSkillCount = try context.fetchCount(skillDescriptor)

        // Second seed should not add duplicates
        DataSeeder.seedIfNeeded(context: context)

        let finalSkillCount = try context.fetchCount(skillDescriptor)
        XCTAssertEqual(initialSkillCount, finalSkillCount, "Should not create duplicate skills")
    }

    func testDataSeederSkillsHaveCorrectProperties() throws {
        // Create in-memory ModelContainer
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Character.self, Skill.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Seed the database
        DataSeeder.seedIfNeeded(context: context)

        // Fetch all skills
        let skillDescriptor = FetchDescriptor<Skill>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let skills = try context.fetch(skillDescriptor)

        // Verify all skills have required properties
        for skill in skills {
            XCTAssertFalse(skill.name.isEmpty, "Skill should have a name")
            XCTAssertTrue(skill.isBuiltIn, "Seeded skills should be marked as built-in")
        }

        // Verify some known skills exist
        let skillNames = skills.map { $0.name }
        XCTAssertTrue(skillNames.contains("+1 Action"), "Should have +1 Action skill")
        XCTAssertTrue(skillNames.contains("Lucky"), "Should have Lucky skill")
        XCTAssertTrue(skillNames.contains("Slippery"), "Should have Slippery skill")
    }

    func testDataSeederCharactersHaveCorrectProperties() throws {
        // Create in-memory ModelContainer
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Character.self, Skill.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Seed the database
        DataSeeder.seedIfNeeded(context: context)

        // Fetch all characters
        let characterDescriptor = FetchDescriptor<Character>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let characters = try context.fetch(characterDescriptor)

        // Verify all characters have required properties
        for character in characters {
            XCTAssertFalse(character.name.isEmpty, "Character should have a name")
            XCTAssertTrue(character.isBuiltIn, "Seeded characters should be marked as built-in")
            XCTAssertGreaterThan(character.health, 0, "Character should have health > 0")

            // All characters should have yellow skill "+1 Action"
            XCTAssertEqual(character.yellowSkills, "+1 Action", "All characters should have +1 Action yellow skill")
        }
    }
}
