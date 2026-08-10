import XCTest
@testable import TEOP1
@testable import TECore

final class DrumPatchCodecTests: XCTestCase {
    func testRoundTripDecodesSamePatch() throws {
        var patch = DrumPatch.defaultPatch
        patch.name = "test-kit"
        let samples: [Float] = Array(repeating: 0.1, count: 2000)
        let data = try DrumPatchCodec.encode(patch, samples: samples, sampleRate: 44100)

        let decoded = try DrumPatchCodec.decode(data)
        XCTAssertEqual(decoded.name, "test-kit")
        XCTAssertEqual(decoded.end.count, 24)
        XCTAssertEqual(decoded.drumVersion, 2)
    }

    func testEncodePadsToMultipleOfFour() throws {
        let patch = DrumPatch.defaultPatch
        let samples: [Float] = Array(repeating: 0.1, count: 999) // odd count on purpose
        let data = try DrumPatchCodec.encode(patch, samples: samples, sampleRate: 44100)
        XCTAssertEqual((data.count - 8) % 4, 0)
    }

    func testDecodesRealTeoperatorFixture() throws {
        guard let url = Bundle.module.url(forResource: "playmode_0_poly", withExtension: "aif", subdirectory: "Fixtures") else {
            XCTFail("fixture not found in test bundle")
            return
        }
        let data = try Data(contentsOf: url)
        // These are synth patches, not drum patches, in teoperator's own
        // fixture set — this test only confirms the op-1 JSON block can be
        // located and parsed as valid JSON, not that it matches DrumPatch's
        // schema.
        let jsonData = try SynthPatchCodec.extractOP1JSON(from: data)
        let json = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(json)
    }
}
