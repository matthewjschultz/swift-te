import XCTest
@testable import TEOPXY

final class ValueConversionsTests: XCTestCase {
    func testPercentToInternalKnownValues() {
        XCTAssertEqual(ValueConversions.percentToInternal(0), 0)
        XCTAssertEqual(ValueConversions.percentToInternal(100), 32767)
        XCTAssertEqual(ValueConversions.percentToInternal(50), 16384)
    }

    func testInternalToPercentKnownValues() {
        XCTAssertEqual(ValueConversions.internalToPercent(0), 0)
        XCTAssertEqual(ValueConversions.internalToPercent(32767), 100)
        XCTAssertEqual(ValueConversions.internalToPercent(16384), 50)
    }

    func testRoundTripIsStable() {
        for percentInt in stride(from: 0, through: 100, by: 10) {
            let internalValue = ValueConversions.percentToInternal(Double(percentInt))
            let back = ValueConversions.internalToPercent(internalValue)
            XCTAssertTrue(abs(back - percentInt) <= 1, "expected \(back) to be within 1 of \(percentInt)")
        }
    }
}
