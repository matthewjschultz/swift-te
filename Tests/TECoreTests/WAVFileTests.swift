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

    func testEncodedThrowsOnZeroSampleRate() {
        // The smpl chunk divides by the sample rate to derive a sample period.
        let wav = WAVFile(sampleRate: 0, bitDepth: 16, channelCount: 1, samples: [0, 0], rootNote: 60)
        XCTAssertThrowsError(try wav.encoded()) { error in
            XCTAssertEqual(error as? WAVError, .invalidSampleRate(0))
        }
    }

    func testEncodedThrowsOnZeroChannelCount() {
        let wav = WAVFile(sampleRate: 44100, bitDepth: 16, channelCount: 0, samples: [0, 0])
        XCTAssertThrowsError(try wav.encoded()) { error in
            XCTAssertEqual(error as? WAVError, .invalidChannelCount(0))
        }
    }

    // MARK: - Structurally valid, internally inconsistent files

    func testDecodeRejectsFmtChunkDeclaringTooSmallABody() {
        // The fields decode reads live within the first 16 bytes of the body.
        let data = hostileWAV(chunks: [fmtChunk(bodyBytes: 12), dataChunk()])
        expect(.truncatedChunk("fmt "), decoding: data)
    }

    func testDecodeRejectsSMPLChunkDeclaringTooSmallABody() {
        // Loop points live at +44/+48, so a 36-byte body can't hold them.
        let data = hostileWAV(chunks: [fmtChunk(), smplChunk(bodyBytes: 36), dataChunk()])
        expect(.truncatedChunk("smpl"), decoding: data)
    }

    func testDecodeRejectsZeroChannelCount() {
        let data = hostileWAV(chunks: [fmtChunk(channels: 0), dataChunk()])
        expect(.invalidChannelCount(0), decoding: data)
    }

    func testDecodeRejectsZeroSampleRate() {
        let data = hostileWAV(chunks: [fmtChunk(sampleRate: 0), dataChunk()])
        expect(.invalidSampleRate(0), decoding: data)
    }

    // MARK: - Hostile file construction

    private func expect(_ expected: WAVError, decoding data: Data, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try WAVFile.decode(data), file: file, line: line) { error in
            XCTAssertEqual(error as? WAVError, expected, file: file, line: line)
        }
    }

    private func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 24 & 0xFF)]
    }

    private func le16(_ v: UInt16) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF)]
    }

    private func wavChunk(_ id: String, body: [UInt8]) -> [UInt8] {
        Array(id.utf8) + le32(UInt32(body.count)) + body
    }

    /// `bodyBytes` truncates the body to that many bytes, so the declared size
    /// stays consistent with what's present while being too small for the
    /// fields the format puts inside the chunk.
    private func fmtChunk(channels: UInt16 = 1, sampleRate: UInt32 = 44100, bitDepth: UInt16 = 16, bodyBytes: Int? = nil) -> [UInt8] {
        let blockAlign = channels * (bitDepth / 8)
        var body = [UInt8]()
        body += le16(1) // PCM
        body += le16(channels)
        body += le32(sampleRate)
        body += le32(sampleRate * UInt32(blockAlign))
        body += le16(blockAlign)
        body += le16(bitDepth)
        return wavChunk("fmt ", body: Array(body.prefix(bodyBytes ?? body.count)))
    }

    private func smplChunk(bodyBytes: Int? = nil) -> [UInt8] {
        let body = [UInt8](repeating: 0, count: 60)
        return wavChunk("smpl", body: Array(body.prefix(bodyBytes ?? body.count)))
    }

    private func dataChunk() -> [UInt8] {
        wavChunk("data", body: [0, 0, 0, 0])
    }

    private func hostileWAV(chunks: [[UInt8]]) -> Data {
        let body = chunks.flatMap { $0 }
        return Data(Array("RIFF".utf8) + le32(UInt32(4 + body.count)) + Array("WAVE".utf8) + body)
    }
}
