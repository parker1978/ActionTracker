import XCTest
@testable import CoreDomain

final class CoreDomainTests: XCTestCase {
    func testActionTypeDisplayNames() {
        XCTAssertEqual(ActionType.action.displayName, "Action")
        XCTAssertEqual(ActionType.combat.displayName, "Combat")
        XCTAssertEqual(ActionType.melee.displayName, "Melee")
    }

    func testSkillLevelXPRanges() {
        XCTAssertTrue(SkillLevel.blue.xpRange.contains(0))
        XCTAssertTrue(SkillLevel.yellow.xpRange.contains(7))
        XCTAssertTrue(SkillLevel.orange.xpRange.contains(19))
        XCTAssertTrue(SkillLevel.red.xpRange.contains(43))
    }

    func testInventoryFormatter() {
        let weapons = ["Sword", "Bow", "Shield"]
        let joined = InventoryFormatter.join(weapons)
        let parsed = InventoryFormatter.parse(joined)
        XCTAssertEqual(weapons, parsed)
    }
}
