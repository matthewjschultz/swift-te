import XCTest
@testable import TEOP1
@testable import TECore

final class SynthPatchCodecTests: XCTestCase {
    func testEncodeProducesValidAIFF() throws {
        let patch = SynthPatch.synthSample(baseFrequency: 440.0)
        let samples: [Float] = Array(repeating: 0.1, count: 1000)
        let data = try SynthPatchCodec.encode(patch, samples: samples, sampleRate: 44100)

        XCTAssertEqual(data.prefix(4), "FORM".data(using: .ascii))
        let decodedAIFF = try AIFFFile.decode(data)
        XCTAssertEqual(decodedAIFF.sampleRate, 44100)
        XCTAssertEqual(decodedAIFF.samples.count, 1000)
    }

    func testEncodeThrowsWhenPatchCannotBeSerialized() {
        // JSONEncoder rejects non-conforming Doubles by default. Swallowing
        // that produced an AIFF with an empty op-1 chunk, reported as success.
        var patch = SynthPatch.synthSample(baseFrequency: 440.0)
        patch.baseFreq = .nan
        XCTAssertThrowsError(try SynthPatchCodec.encode(patch, samples: [0, 0, 0, 0], sampleRate: 44100)) { error in
            XCTAssertEqual(error as? SynthPatchCodecError, .encodingFailed)
        }
    }

    func testSpliceThrowsWhenSSNDChunkIsAbsent() throws {
        // A FORM/AIFF container carrying only a COMM chunk: there's nowhere to
        // splice the op-1 payload, which used to return the input unchanged.
        var aiff = Data("FORM".utf8)
        aiff.append(contentsOf: [0, 0, 0, 4])
        aiff.append(contentsOf: Array("AIFF".utf8))
        XCTAssertThrowsError(try SynthPatchCodec.spliceAPPLChunk(into: aiff, jsonData: Data("{}".utf8), paddingMultiple: 2)) { error in
            XCTAssertEqual(error as? SynthPatchCodecError, .missingSSNDChunk)
        }
    }

    func testRoundTripDecodesSamePatch() throws {
        let patch = SynthPatch.synthSample(baseFrequency: 330.0)
        let samples: [Float] = Array(repeating: 0.2, count: 500)
        let data = try SynthPatchCodec.encode(patch, samples: samples, sampleRate: 44100)

        let decoded = try SynthPatchCodec.decode(data)
        XCTAssertEqual(decoded.baseFreq, 330.0)
        XCTAssertEqual(decoded.type, "sampler")
        XCTAssertEqual(decoded.fxType, patch.fxType)
    }

    func testDecodeThrowsOnMissingChunk() throws {
        let plainAIFF = try AIFFFile(sampleRate: 44100, bitDepth: 16, channelCount: 1, samples: [0.1, 0.2]).encoded()
        XCTAssertThrowsError(try SynthPatchCodec.decode(plainAIFF))
    }

    func testRoundTripSurvivesUnbalancedBraceInName() throws {
        // A lone `}` with no matching `{` is the case a naive, non-string-aware
        // brace counter gets wrong: it decrements depth to 0 mid-string and
        // truncates the JSON right there, instead of skipping past it because
        // it's inside a quoted string value.
        var patch = SynthPatch.synthSample(baseFrequency: 220.0)
        patch.name = "closing}brace"
        let samples: [Float] = Array(repeating: 0.15, count: 200)
        let data = try SynthPatchCodec.encode(patch, samples: samples, sampleRate: 44100)

        let decoded = try SynthPatchCodec.decode(data)
        XCTAssertEqual(decoded.name, "closing}brace")
        XCTAssertEqual(decoded.baseFreq, 220.0)
    }
}
