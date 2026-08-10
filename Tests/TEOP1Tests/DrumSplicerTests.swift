import XCTest
@testable import TEOP1

final class DrumSplicerTests: XCTestCase {
    func testEvenSlicesDividesEqually() {
        let samples = [Float](repeating: 0.5, count: 1000)
        let ranges = DrumSplicer.splice(samples, sampleRate: 44100, mode: .evenSlices(count: 4))
        XCTAssertEqual(ranges.count, 4)
        XCTAssertEqual(ranges.first?.start, 0)
        XCTAssertEqual(ranges.last?.end, 1000)
        for i in 1..<ranges.count {
            XCTAssertEqual(ranges[i - 1].end, ranges[i].start)
        }
    }

    func testSilenceSplitsAtQuietGaps() {
        // Two loud bursts separated by a long silent gap.
        var samples = [Float](repeating: 0.8, count: 4410)     // 0.1s loud
        samples += [Float](repeating: 0.0, count: 22050)        // 0.5s silent
        samples += [Float](repeating: 0.8, count: 4410)         // 0.1s loud

        let ranges = DrumSplicer.splice(samples, sampleRate: 44100, mode: .silence(thresholdDB: -40, minSilenceSeconds: 0.2))
        XCTAssertEqual(ranges.count, 2)
    }

    func testOnsetsFindsApproximatelyRightCount() {
        // A synthetic click train: five short loud bursts separated by silence.
        var samples: [Float] = []
        for _ in 0..<5 {
            samples += [Float](repeating: 0.9, count: 200)
            samples += [Float](repeating: 0.0, count: 4000)
        }
        let ranges = DrumSplicer.splice(samples, sampleRate: 44100, mode: .onsets(sensitivity: 0.3))
        // Approximate — the design commits to "roughly right", not exact.
        XCTAssertTrue(ranges.count >= 3 && ranges.count <= 7, "expected roughly 5 onsets, got \(ranges.count)")
    }
}
