import XCTest
@testable import DataLayer

final class DataLayerTests: XCTestCase {
    func testModuleVersion() {
        XCTAssertEqual(DataLayer.version, "1.0.0")
    }
}
