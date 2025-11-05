import XCTest
@testable import CoreDomain

final class CoreDomainTests: XCTestCase {
    func testModuleVersion() {
        XCTAssertEqual(CoreDomain.version, "1.0.0")
    }
}
