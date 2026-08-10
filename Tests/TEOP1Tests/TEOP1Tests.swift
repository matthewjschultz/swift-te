import XCTest
@testable import TEOP1

final class TEOP1Tests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertFalse(TEOP1Version.isEmpty)
    }
}
