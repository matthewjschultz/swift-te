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

    // MARK: - Structurally valid, internally inconsistent files

    func testDecodeRejectsSSNDChunkLargerThanFile() {
        let data = hostileAIFF(chunks: [
            commChunk(),
            ssndChunk(declaredSize: 0xFFFF_FF00)
        ])
        expect(AIFFError.truncatedData, decoding: data)
    }

    func testDecodeRejectsSSNDChunkTooSmallForItsHeader() {
        // A valid SSND body is at least 8 bytes (offset + block size).
        let data = hostileAIFF(chunks: [
            commChunk(),
            ssndChunk(declaredSize: 4)
        ])
        expect(AIFFError.truncatedData, decoding: data)
    }

    func testDecodeRejectsCOMMChunkDeclaringTooSmallABody() {
        // Channels and bit depth are present and valid; the declared size cuts
        // the body off before the sample rate, so reading it would pull in
        // whatever bytes follow the chunk. Declared size matches the physical
        // body, so the chunk walk still finds SSND.
        let data = hostileAIFF(chunks: [
            aiffChunk("COMM", body: Array(commBody().prefix(8))),
            ssndChunk()
        ])
        expect(AIFFError.truncatedData, decoding: data)
    }

    func testDecodeRejectsCOMMChunkRunningPastEndOfFile() {
        // SSND first so it's still locatable, then a COMM that claims a full
        // 18-byte body while the file ends 8 bytes in — the sample rate would
        // be read from past the end of the data.
        let data = hostileAIFF(chunks: [
            ssndChunk(),
            aiffChunk("COMM", declaredSize: 18, body: Array(commBody().prefix(8)))
        ])
        expect(AIFFError.truncatedData, decoding: data)
    }

    func testDecodeRejectsZeroChannelCount() {
        let data = hostileAIFF(chunks: [commChunk(channels: 0), ssndChunk()])
        expect(AIFFError.invalidChannelCount(0), decoding: data)
    }

    func testDecodeRejectsZeroSampleRate() {
        let data = hostileAIFF(chunks: [commChunk(sampleRate: 0), ssndChunk()])
        expect(AIFFError.invalidSampleRate, decoding: data)
    }

    func testEncodeRejectsZeroChannelCount() {
        let aiff = AIFFFile(sampleRate: 44100, bitDepth: 16, channelCount: 0, samples: [0.1, 0.2])
        XCTAssertThrowsError(try aiff.encoded()) { error in
            XCTAssertEqual(error as? AIFFError, .invalidChannelCount(0))
        }
    }

    // MARK: - Hostile file construction

    private func expect(_ expected: AIFFError, decoding data: Data, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try AIFFFile.decode(data), file: file, line: line) { error in
            XCTAssertEqual(error as? AIFFError, expected, file: file, line: line)
        }
    }

    private func be32(_ v: UInt32) -> [UInt8] {
        [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]
    }

    /// Builds a chunk whose declared size can be made to disagree with the
    /// number of bytes actually present.
    private func aiffChunk(_ id: String, declaredSize: UInt32? = nil, body: [UInt8]) -> [UInt8] {
        Array(id.utf8) + be32(declaredSize ?? UInt32(body.count)) + body
    }

    /// The 18 bytes a COMM body is required to hold: channels (2),
    /// frames (4), bit depth (2), sample rate (10).
    private func commBody(channels: UInt16 = 1, frames: UInt32 = 4, bitDepth: UInt16 = 16, sampleRate: Double = 44100) -> [UInt8] {
        var body = [UInt8]()
        body += [UInt8(channels >> 8), UInt8(channels & 0xFF)]
        body += be32(frames)
        body += [UInt8(bitDepth >> 8), UInt8(bitDepth & 0xFF)]
        body += AIFFFile.extended80(from: sampleRate)
        return body
    }

    private func commChunk(channels: UInt16 = 1, frames: UInt32 = 4, bitDepth: UInt16 = 16, sampleRate: Double = 44100) -> [UInt8] {
        aiffChunk("COMM", body: commBody(channels: channels, frames: frames, bitDepth: bitDepth, sampleRate: sampleRate))
    }

    private func ssndChunk(declaredSize: UInt32? = nil) -> [UInt8] {
        // offset (4) + block size (4) + 8 bytes of sample data
        let body = be32(0) + be32(0) + [UInt8](repeating: 0, count: 8)
        return aiffChunk("SSND", declaredSize: declaredSize, body: body)
    }

    private func hostileAIFF(chunks: [[UInt8]]) -> Data {
        let body = chunks.flatMap { $0 }
        return Data(Array("FORM".utf8) + be32(UInt32(4 + body.count)) + Array("AIFF".utf8) + body)
    }
}
