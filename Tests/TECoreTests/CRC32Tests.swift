import XCTest
@testable import TECore

final class CRC32Tests: XCTestCase {
    func testKnownChecksum() {
        // "123456789" is the standard CRC-32 test vector; expected value is well known.
        let data = "123456789".data(using: .utf8)!
        XCTAssertEqual(CRC32.checksum(data), 0xCBF43926)
    }

    func testEmptyData() {
        XCTAssertEqual(CRC32.checksum(Data()), 0)
    }
}
