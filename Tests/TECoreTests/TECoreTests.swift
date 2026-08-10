import XCTest
@testable import TECore

final class TECoreTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertFalse(TECoreVersion.isEmpty)
    }
}
