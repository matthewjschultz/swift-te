import XCTest
@testable import TEOP1

final class SynthPatchTests: XCTestCase {
    func testDefaultSamplerMatchesKnownValues() {
        let patch = SynthPatch.defaultSampler
        XCTAssertEqual(patch.type, "sampler")
        XCTAssertEqual(patch.synthVersion, 1)
        XCTAssertEqual(patch.baseFreq ?? 0, 261.6253662109375, accuracy: 0.0000001)
        XCTAssertEqual(patch.adsr.count, 8)
        XCTAssertEqual(patch.fxType, "delay")
    }

    func testSynthSampleOverridesBaseFrequency() {
        let patch = SynthPatch.synthSample(baseFrequency: 220.0)
        XCTAssertEqual(patch.baseFreq ?? 0, 220.0)
        XCTAssertEqual(patch.type, "sampler")
    }

    func testEncodesToExpectedJSONKeys() throws {
        let data = try JSONEncoder().encode(SynthPatch.defaultCluster)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["synth_version"] as? Int, 2)
        XCTAssertEqual(json?["fx_type"] as? String, "nitro")
        XCTAssertNotNil(json?["adsr"])
    }
}
