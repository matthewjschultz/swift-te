import XCTest
@testable import TECore

final class AIFFFileTests: XCTestCase {
    func testRoundTrip16Bit() throws {
        let original = AIFFFile(sampleRate: 44100, bitDepth: 16, channelCount: 1, samples: [0.0, 0.5, -0.5, 1.0, -1.0])
        let decoded = try AIFFFile.decode(try original.encoded())
        XCTAssertEqual(decoded.sampleRate, 44100)
        XCTAssertEqual(decoded.bitDepth, 16)
        XCTAssertEqual(decoded.channelCount, 1)
        for (a, b) in zip(original.samples, decoded.samples) {
            XCTAssertEqual(a, b, accuracy: 0.0001)
        }
    }

    func testChunkRangeLocatesSSND() throws {
        let aiff = AIFFFile(sampleRate: 44100, bitDepth: 16, channelCount: 1, samples: [0.1, 0.2])
        let data = try aiff.encoded()
        let range = AIFFFile.chunkRange(ofID: "SSND", in: data)
        XCTAssertNotNil(range)
        XCTAssertEqual(data.subdata(in: range!.lowerBound..<(range!.lowerBound + 4)), "SSND".data(using: .ascii))
    }

    func testDecodeRejectsNonFORM() {
        let garbage = "definitely not an aiff file".data(using: .utf8)!
        XCTAssertThrowsError(try AIFFFile.decode(garbage))
    }

    func testEncodeThrowsForUnsupportedBitDepth() {
        let aiff = AIFFFile(sampleRate: 44100, bitDepth: 12, channelCount: 1, samples: [0.5])
        XCTAssertThrowsError(try aiff.encoded()) { error in
            if case AIFFError.unsupportedBitDepth(12) = error {
                return
            }
            XCTFail("Expected unsupportedBitDepth(12), got \(error)")
        }
    }
}
