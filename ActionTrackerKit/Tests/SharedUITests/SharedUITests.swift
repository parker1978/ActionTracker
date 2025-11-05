import XCTest
@testable import SharedUI

final class SharedUITests: XCTestCase {
    func testModuleVersion() {
        XCTAssertEqual(SharedUI.version, "1.0.0")
    }
}
