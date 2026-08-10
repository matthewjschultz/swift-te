import XCTest
@testable import TEOPXY

final class TEOPXYTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertFalse(TEOPXYVersion.isEmpty)
    }
}
