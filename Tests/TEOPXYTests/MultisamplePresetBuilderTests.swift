import XCTest
@testable import TEOPXY

final class MultisamplePresetBuilderTests: XCTestCase {
    func testSingleZoneCoversFullKeyRangeBelowItself() {
        let zone = MultisampleZone(samples: [Float](repeating: 0.1, count: 44100), sourceSampleRate: 44100, fileName: "c4.wav", rootNote: 60)
        let preset = MultisamplePresetBuilder.build(name: "keys", zones: [zone])
        XCTAssertEqual(preset.regions.count, 1)
        XCTAssertEqual(preset.regions[0].lokey, 0)
        // Last region's hikey is forced to 127 regardless of rootNote.
        XCTAssertEqual(preset.regions[0].hikey, 127)
        XCTAssertEqual(preset.regions[0].pitchKeycenter, 60)
    }

    func testMultipleZonesSplitKeyRangesSequentially() {
        let zones = [
            MultisampleZone(samples: [Float](repeating: 0.1, count: 1000), sourceSampleRate: 44100, fileName: "a.wav", rootNote: 48),
            MultisampleZone(samples: [Float](repeating: 0.1, count: 1000), sourceSampleRate: 44100, fileName: "b.wav", rootNote: 60),
            MultisampleZone(samples: [Float](repeating: 0.1, count: 1000), sourceSampleRate: 44100, fileName: "c.wav", rootNote: 72),
        ]
        let preset = MultisamplePresetBuilder.build(name: "keys", zones: zones)
        XCTAssertEqual(preset.regions[0].lokey, 0)
        XCTAssertEqual(preset.regions[0].hikey, 48)
        XCTAssertEqual(preset.regions[1].lokey, 49)
        XCTAssertEqual(preset.regions[1].hikey, 60)
        XCTAssertEqual(preset.regions[2].lokey, 61)
        // Last region's hikey is always forced to 127.
        XCTAssertEqual(preset.regions[2].hikey, 127)
    }

    func testDefaultLoopPointsAreTenAndNinetyPercent() {
        let zone = MultisampleZone(samples: [Float](repeating: 0.1, count: 44100), sourceSampleRate: 44100, fileName: "c4.wav", rootNote: 60)
        let preset = MultisamplePresetBuilder.build(name: "keys", zones: [zone])
        XCTAssertEqual(preset.regions[0].loopStart, 4410)
        XCTAssertEqual(preset.regions[0].loopEnd, 39690)
    }

    func testCutAtLoopEndPadsFramecount() {
        let zone = MultisampleZone(samples: [Float](repeating: 0.1, count: 44100), sourceSampleRate: 44100, fileName: "c4.wav", rootNote: 60)
        let preset = MultisamplePresetBuilder.build(name: "keys", zones: [zone], cutAtLoopEnd: true)
        // loopEnd (39690) + LOOP_END_PADDING (5)
        XCTAssertEqual(preset.regions[0].framecount, 39695)
        XCTAssertEqual(preset.regions[0].sampleEnd, 39695)
    }

    func testBuildUsesBaseMultisampleDefaults() {
        let zone = MultisampleZone(samples: [Float](repeating: 0.1, count: 1000), sourceSampleRate: 44100, fileName: "c4.wav", rootNote: 60)
        let preset = MultisamplePresetBuilder.build(name: "keys", zones: [zone])
        XCTAssertEqual(preset.type, "multisampler")
        XCTAssertEqual(preset.platform, "OP-XY")
    }

    func testZeroSourceSampleRateProducesDegenerateRegionWithoutCrashing() {
        // Dividing the sample count by a zero rate yields an infinite
        // duration, which has no representation as a frame count.
        let zone = MultisampleZone(samples: [0.1, 0.2], sourceSampleRate: 0, fileName: "a.wav", rootNote: 60)
        let preset = MultisamplePresetBuilder.build(name: "keys", zones: [zone])
        XCTAssertEqual(preset.regions.count, 1)
        XCTAssertEqual(preset.regions[0].framecount, 0)
        XCTAssertEqual(preset.regions[0].sampleStart, 0)
        XCTAssertEqual(preset.regions[0].sampleEnd, 0)
        XCTAssertEqual(preset.regions[0].loopStart, 0)
        XCTAssertEqual(preset.regions[0].loopEnd, 0)
    }

    func testEmptySampleZoneProducesDegenerateRegionWithoutCrashing() {
        let zone = MultisampleZone(samples: [], sourceSampleRate: 44100, fileName: "empty.wav", rootNote: 60)
        let preset = MultisamplePresetBuilder.build(name: "keys", zones: [zone])
        XCTAssertEqual(preset.regions.count, 1)
        XCTAssertEqual(preset.regions[0].framecount, 0)
        XCTAssertEqual(preset.regions[0].sampleStart, 0)
        XCTAssertEqual(preset.regions[0].sampleEnd, 0)
        XCTAssertEqual(preset.regions[0].loopStart, 0)
        XCTAssertEqual(preset.regions[0].loopEnd, 0)
        XCTAssertEqual(preset.regions[0].pitchKeycenter, 60)
        XCTAssertEqual(preset.regions[0].sample, "empty.wav")
    }
}
