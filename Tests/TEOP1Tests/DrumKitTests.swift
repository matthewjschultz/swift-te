import XCTest
@testable import TEOP1

final class DrumKitTests: XCTestCase {
    func testBuildFromClipsSplicesAtFileBoundaries() {
        let clips: [[Float]] = [
            [Float](repeating: 0.1, count: 4410),
            [Float](repeating: 0.2, count: 4410),
            [Float](repeating: 0.3, count: 4410),
        ]
        let result = DrumKit.build(from: clips, sampleRate: 44100)
        XCTAssertEqual(result.samples.count, 13230)
        XCTAssertEqual(result.sampleRate, 44100)
        // First three slots' start points should be non-decreasing and
        // roughly track the 0.1s clip boundaries once converted to OP1 units.
        XCTAssertEqual(result.patch.start[0], 0)
        XCTAssertGreaterThan(result.patch.start[1], result.patch.start[0])
        XCTAssertGreaterThan(result.patch.start[2], result.patch.start[1])
    }

    func testBuildFromClipsCapsAt24Slots() {
        let clips: [[Float]] = Array(repeating: [Float](repeating: 0.1, count: 100), count: 30)
        let result = DrumKit.build(from: clips, sampleRate: 44100)
        XCTAssertEqual(result.patch.start.count, 24)
        XCTAssertEqual(result.patch.end.count, 24)
    }

    func testBuildSplicingUsesGivenMode() {
        let samples = [Float](repeating: 0.5, count: 4410)
        let result = DrumKit.build(splicing: samples, sampleRate: 44100, mode: .evenSlices(count: 4))
        XCTAssertEqual(result.samples.count, 4410)
        XCTAssertGreaterThan(result.patch.start[1], result.patch.start[0])
    }
}
