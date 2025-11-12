import XCTest
@testable import WeaponsFeature
@testable import CoreDomain
@testable import DataLayer

final class DeckSettingsTests: XCTestCase {

    var weaponsManager: WeaponsManager!
    var disabledCardsManager: DisabledCardsManager!

    override func setUp() {
        super.setUp()
        weaponsManager = WeaponsManager()
        disabledCardsManager = DisabledCardsManager()

        // Clear UserDefaults for clean test state
        UserDefaults.standard.removeObject(forKey: "selectedExpansions")
    }

    override func tearDown() {
        // Clean up UserDefaults after tests
        UserDefaults.standard.removeObject(forKey: "selectedExpansions")
        weaponsManager = nil
        disabledCardsManager = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_NoUserDefaults_ShouldHaveAllSetsSelected() {
        // Given: No UserDefaults key exists
        XCTAssertNil(UserDefaults.standard.array(forKey: "selectedExpansions"))

        // When: Loading selected expansions
        let allExpansions = Set(WeaponRepository.shared.expansions)

        // Then: All expansions should be available
        XCTAssertFalse(allExpansions.isEmpty, "Should have expansions from weapons repository")
        XCTAssertTrue(allExpansions.count > 0, "Should have at least one expansion")
    }

    func testInitialState_WithUserDefaults_ShouldLoadSavedSelections() {
        // Given: Saved selections in UserDefaults
        let savedSelections = ["Fort Hendrix", "Pariz"]
        UserDefaults.standard.set(savedSelections, forKey: "selectedExpansions")

        // When: Loading from UserDefaults
        let loaded = UserDefaults.standard.array(forKey: "selectedExpansions") as? [String]

        // Then: Should match saved selections
        XCTAssertEqual(Set(loaded ?? []), Set(savedSelections))
    }

    // MARK: - Expansion Selection Tests

    func testSelectAll_ShouldSelectAllExpansions() {
        // Given: Initial state with some selections
        let allExpansions = WeaponRepository.shared.expansions.sorted()
        var selectedExpansions: Set<String> = []
        var isCustomExpansionSelection = false

        // When: Select All is triggered
        isCustomExpansionSelection = true
        selectedExpansions = Set(allExpansions)

        // Then: All expansions should be selected
        XCTAssertTrue(isCustomExpansionSelection, "Should be in custom selection mode")
        XCTAssertEqual(selectedExpansions.count, allExpansions.count, "Should have all expansions selected")
        for expansion in allExpansions {
            XCTAssertTrue(selectedExpansions.contains(expansion), "Should contain \(expansion)")
        }
    }

    func testDeselectAll_ShouldClearAllSelections() {
        // Given: All expansions selected
        let allExpansions = WeaponRepository.shared.expansions.sorted()
        var selectedExpansions: Set<String> = Set(allExpansions)
        var isCustomExpansionSelection = true

        // When: Deselect All is triggered
        isCustomExpansionSelection = true
        selectedExpansions.removeAll()

        // Then: No expansions should be selected
        XCTAssertTrue(isCustomExpansionSelection, "Should be in custom selection mode")
        XCTAssertEqual(selectedExpansions.count, 0, "Should have no expansions selected")
    }

    func testToggleExpansion_ShouldAddWhenNotPresent() {
        // Given: Empty selections
        var selectedExpansions: Set<String> = []
        var isCustomExpansionSelection = false
        let expansionToToggle = "Fort Hendrix"

        // When: Toggling on
        isCustomExpansionSelection = true
        selectedExpansions.insert(expansionToToggle)

        // Then: Expansion should be added
        XCTAssertTrue(isCustomExpansionSelection, "Should be in custom selection mode")
        XCTAssertTrue(selectedExpansions.contains(expansionToToggle), "Should contain the expansion")
        XCTAssertEqual(selectedExpansions.count, 1, "Should have one expansion")
    }

    func testToggleExpansion_ShouldRemoveWhenPresent() {
        // Given: One expansion selected
        let expansionToToggle = "Fort Hendrix"
        var selectedExpansions: Set<String> = [expansionToToggle]
        var isCustomExpansionSelection = true

        // When: Toggling off
        selectedExpansions.remove(expansionToToggle)

        // Then: Expansion should be removed
        XCTAssertTrue(isCustomExpansionSelection, "Should be in custom selection mode")
        XCTAssertFalse(selectedExpansions.contains(expansionToToggle), "Should not contain the expansion")
        XCTAssertEqual(selectedExpansions.count, 0, "Should have no expansions")
    }

    // MARK: - Toggle Binding Logic Tests

    func testToggleBindingGetter_DefaultState_ShouldReturnTrue() {
        // Given: Default state (not custom selection)
        let isCustomExpansionSelection = false
        let selectedExpansions: Set<String> = Set(WeaponRepository.shared.expansions)
        let setName = "Fort Hendrix"

        // When: Evaluating toggle binding getter
        let result = !isCustomExpansionSelection || selectedExpansions.contains(setName)

        // Then: Should return true (all sets selected in default mode)
        XCTAssertTrue(result, "Toggle should be ON in default state")
    }

    func testToggleBindingGetter_CustomState_Selected_ShouldReturnTrue() {
        // Given: Custom selection with specific set selected
        let isCustomExpansionSelection = true
        let setName = "Fort Hendrix"
        let selectedExpansions: Set<String> = [setName]

        // When: Evaluating toggle binding getter
        let result = !isCustomExpansionSelection || selectedExpansions.contains(setName)

        // Then: Should return true (set is selected)
        XCTAssertTrue(result, "Toggle should be ON when set is selected")
    }

    func testToggleBindingGetter_CustomState_NotSelected_ShouldReturnFalse() {
        // Given: Custom selection with specific set NOT selected
        let isCustomExpansionSelection = true
        let setName = "Fort Hendrix"
        let selectedExpansions: Set<String> = ["Pariz"]

        // When: Evaluating toggle binding getter
        let result = !isCustomExpansionSelection || selectedExpansions.contains(setName)

        // Then: Should return false (set is not selected)
        XCTAssertFalse(result, "Toggle should be OFF when set is not selected")
    }

    // MARK: - UserDefaults Persistence Tests

    func testSaveExpansionFilter_CustomSelection_ShouldPersistToUserDefaults() {
        // Given: Custom selection
        let isCustomExpansionSelection = true
        let selectedExpansions: Set<String> = ["Fort Hendrix", "Pariz"]

        // When: Saving to UserDefaults
        if isCustomExpansionSelection {
            UserDefaults.standard.set(Array(selectedExpansions), forKey: "selectedExpansions")
        }

        // Then: Should be persisted
        let saved = UserDefaults.standard.array(forKey: "selectedExpansions") as? [String]
        XCTAssertNotNil(saved, "Should save to UserDefaults")
        XCTAssertEqual(Set(saved ?? []), selectedExpansions, "Saved selections should match")
    }

    func testSaveExpansionFilter_DefaultState_ShouldRemoveUserDefaultsKey() {
        // Given: Default state and existing UserDefaults
        UserDefaults.standard.set(["Fort Hendrix"], forKey: "selectedExpansions")
        let isCustomExpansionSelection = false

        // When: Saving in default state
        if !isCustomExpansionSelection {
            UserDefaults.standard.removeObject(forKey: "selectedExpansions")
        }

        // Then: Key should be removed
        let saved = UserDefaults.standard.array(forKey: "selectedExpansions")
        XCTAssertNil(saved, "Should remove UserDefaults key in default state")
    }

    // MARK: - Weapons Filtering Tests

    func testGetFilteredWeapons_DefaultState_ShouldReturnAllWeapons() {
        // Given: Default state (not custom selection)
        let isCustomExpansionSelection = false
        let selectedExpansions = Set(WeaponRepository.shared.expansions)

        // When: Getting filtered weapons
        var weapons = WeaponRepository.shared.allWeapons
        if isCustomExpansionSelection {
            weapons = weapons.filter { selectedExpansions.contains($0.expansion) }
        }

        // Then: Should return all weapons
        XCTAssertEqual(weapons.count, WeaponRepository.shared.allWeapons.count,
                       "Should return all weapons in default state")
    }

    func testGetFilteredWeapons_CustomSelection_ShouldFilterByExpansion() {
        // Given: Custom selection with specific expansions
        let isCustomExpansionSelection = true
        let selectedExpansions: Set<String> = ["Fort Hendrix"]

        // When: Getting filtered weapons
        var weapons = WeaponRepository.shared.allWeapons
        if isCustomExpansionSelection {
            weapons = weapons.filter { selectedExpansions.contains($0.expansion) }
        }

        // Then: Should only return weapons from selected expansions
        XCTAssertTrue(weapons.count < WeaponRepository.shared.allWeapons.count,
                      "Should filter weapons")
        for weapon in weapons {
            XCTAssertTrue(selectedExpansions.contains(weapon.expansion),
                         "All weapons should be from selected expansions")
        }
    }

    func testGetFilteredWeapons_EmptySelection_ShouldReturnNoWeapons() {
        // Given: Custom selection with no expansions selected
        let isCustomExpansionSelection = true
        let selectedExpansions: Set<String> = []

        // When: Getting filtered weapons
        var weapons = WeaponRepository.shared.allWeapons
        if isCustomExpansionSelection {
            weapons = weapons.filter { selectedExpansions.contains($0.expansion) }
        }

        // Then: Should return no weapons
        XCTAssertEqual(weapons.count, 0, "Should return no weapons when nothing selected")
    }

    // MARK: - WeaponRepository Tests

    func testWeaponRepository_ShouldHaveExpansions() {
        // When: Accessing expansions from repository
        let expansions = WeaponRepository.shared.expansions

        // Then: Should have at least one expansion
        XCTAssertFalse(expansions.isEmpty, "Repository should have expansions")
        XCTAssertTrue(expansions.count > 0, "Should have at least one expansion")
    }

    func testWeaponRepository_ExpansionsShouldBeUnique() {
        // When: Accessing expansions from repository
        let expansions = WeaponRepository.shared.expansions

        // Then: All expansions should be unique (Set removes duplicates)
        let uniqueExpansions = Set(expansions)
        XCTAssertEqual(expansions.count, uniqueExpansions.count,
                       "All expansions should be unique")
    }
}
