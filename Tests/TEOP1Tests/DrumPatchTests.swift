import XCTest
@testable import TEOP1

final class DrumPatchTests: XCTestCase {
    func testDefaultPatchMatchesKnownValues() {
        let patch = DrumPatch.defaultPatch
        XCTAssertEqual(patch.drumVersion, 2)
        XCTAssertEqual(patch.name, "boombap1")
        XCTAssertEqual(patch.end.count, 24)
        XCTAssertEqual(patch.start.count, 24)
        XCTAssertEqual(patch.end.last, 2_032_606_256)
        XCTAssertEqual(patch.fxType, "delay")
    }

    func testClampSlotBoundsEnforcesRange() {
        var patch = DrumPatch.defaultPatch
        patch.end[0] = OP1.maxEndPoint + 1000
        patch.start[0] = -5
        patch.clampSlotBounds()
        XCTAssertEqual(patch.end[0], OP1.maxEndPoint)
        XCTAssertEqual(patch.start[0], 0)
    }

    func testEncodesToExpectedJSONKeys() throws {
        let data = try JSONEncoder().encode(DrumPatch.defaultPatch)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["drum_version"] as? Int, 2)
        XCTAssertEqual(json?["type"] as? String, "drum")
        XCTAssertNotNil(json?["dyna_env"])
    }
}
