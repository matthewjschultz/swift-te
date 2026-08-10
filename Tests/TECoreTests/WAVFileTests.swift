import XCTest
@testable import TECore

final class WAVFileTests: XCTestCase {
    func testRoundTripWithoutSMPLChunk() throws {
        let original = WAVFile(sampleRate: 44100, bitDepth: 16, channelCount: 1, samples: [0.0, 0.5, -0.5, 1.0, -1.0])
        let decoded = try WAVFile.decode(original.encoded())
        XCTAssertEqual(decoded.sampleRate, 44100)
        XCTAssertEqual(decoded.bitDepth, 16)
        XCTAssertEqual(decoded.channelCount, 1)
        XCTAssertEqual(decoded.samples.count, 5)
        for (a, b) in zip(original.samples, decoded.samples) {
            XCTAssertEqual(a, b, accuracy: 0.0001)
        }
        XCTAssertNil(decoded.rootNote)
    }

    func testRoundTripWithSMPLChunk() throws {
        let original = WAVFile(sampleRate: 44100, bitDepth: 16, channelCount: 1, samples: [0.0, 0.2, 0.4, 0.6, 0.8], rootNote: 60, loopStart: 1, loopEnd: 3)
        let decoded = try WAVFile.decode(original.encoded())
        XCTAssertEqual(decoded.rootNote, 60)
        XCTAssertEqual(decoded.loopStart, 1)
        XCTAssertEqual(decoded.loopEnd, 3)
    }

    func testDecodeRejectsNonRIFF() {
        let garbage = "not a wav file at all".data(using: .utf8)!
        XCTAssertThrowsError(try WAVFile.decode(garbage))
    }

    func testRoundTripWithNilRootNoteAndLoopPoints() throws {
        let original = WAVFile(sampleRate: 44100, bitDepth: 16, channelCount: 1, samples: [0.0, 0.2, 0.4, 0.6, 0.8], rootNote: nil, loopStart: 1, loopEnd: 3)
        let decoded = try WAVFile.decode(original.encoded())
        XCTAssertNil(decoded.rootNote)
        XCTAssertEqual(decoded.loopStart, 1)
        XCTAssertEqual(decoded.loopEnd, 3)
    }

    func testEncodedThrowsOnUnsupportedBitDepth() {
        let wav = WAVFile(sampleRate: 44100, bitDepth: 12, channelCount: 1, samples: [0.0, 0.5])
        XCTAssertThrowsError(try wav.encoded()) { error in
            guard case WAVError.unsupportedBitDepth(12) = error else {
                XCTFail("Expected unsupportedBitDepth(12), got \(error)")
                return
            }
        }
    }
}
