import XCTest
@testable import TECore

final class PCMTests: XCTestCase {
    func testDownmixAveragesChannels() {
        let left: [Float] = [1.0, 0.0, -1.0]
        let right: [Float] = [1.0, 1.0, -1.0]
        XCTAssertEqual(PCM.downmix([left, right]), [1.0, 0.5, -1.0])
    }

    func testResampleIdentityWhenRatesMatch() {
        let input: [Float] = [0.1, 0.2, 0.3]
        XCTAssertEqual(PCM.resample(input, from: 44100, to: 44100), input)
    }

    func testResampleHalvesLengthWhenDownsamplingByHalf() {
        let input: [Float] = Array(repeating: 0.5, count: 1000)
        let output = PCM.resample(input, from: 44100, to: 22050)
        XCTAssertEqual(output.count, 500)
    }

    func testResampleReturnsEmptyForZeroSourceRate() {
        // Scaling source positions by 1/sourceRate produces infinity, which
        // then has no representation as an index.
        XCTAssertEqual(PCM.resample([0.1, 0.2, 0.3], from: 0, to: 44100), [])
    }

    func testPeakFindsMaxAbsoluteValue() {
        XCTAssertEqual(PCM.peak([0.1, -0.8, 0.3]), 0.8, accuracy: 0.0001)
    }

    func testRMSOfConstantSignal() {
        // RMS of a constant 0.5 signal is 0.5
        XCTAssertEqual(PCM.rms(Array(repeating: 0.5, count: 100)), 0.5, accuracy: 0.0001)
    }

    func testNormalizedScalesToTargetPeak() {
        let input: [Float] = [0.1, -0.25, 0.2]
        let output = PCM.normalized(input, targetPeakDB: 0.0)
        XCTAssertEqual(PCM.peak(output), 1.0, accuracy: 0.0001)
    }

    func testNearestZeroCrossingFindsSignChange() {
        let samples: [Float] = [1.0, 0.5, 0.1, -0.1, -0.5, -1.0]
        let crossing = PCM.nearestZeroCrossing(samples, around: 2, searchRadius: 3)
        // The sign changes between index 2 (0.1) and index 3 (-0.1).
        XCTAssertTrue(crossing == 2 || crossing == 3)
    }
}
