import XCTest
@testable import TEOPXY

final class DrumPresetBuilderTests: XCTestCase {
    func testSingleSlotProducesOneRegionAtFirstNote() {
        let slot = DrumSlot(samples: [Float](repeating: 0.1, count: 44100), sourceSampleRate: 44100, fileName: "kick.wav")
        let regions = DrumPresetBuilder.regions(for: [slot], targetSampleRate: nil)
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions[0].hikey, 53)
        XCTAssertEqual(regions[0].lokey, 53)
        XCTAssertEqual(regions[0].pitchKeycenter, 60)
        XCTAssertEqual(regions[0].sample, "kick.wav")
        XCTAssertEqual(regions[0].framecount, 44100)
        XCTAssertEqual(regions[0].sampleStart, 0)
        XCTAssertEqual(regions[0].sampleEnd, 44100)
    }

    func testMultipleSlotsAssignSequentialNotesStartingAtFSharp3() {
        let slots = (0..<3).map { i in
            DrumSlot(samples: [Float](repeating: 0.1, count: 1000), sourceSampleRate: 44100, fileName: "s\(i).wav")
        }
        let regions = DrumPresetBuilder.regions(for: slots, targetSampleRate: nil)
        XCTAssertEqual(regions.map(\.hikey), [53, 54, 55])
    }

    func testCapsAt24Slots() {
        let slots = (0..<30).map { i in
            DrumSlot(samples: [Float](repeating: 0.1, count: 100), sourceSampleRate: 44100, fileName: "s\(i).wav")
        }
        let regions = DrumPresetBuilder.regions(for: slots, targetSampleRate: nil)
        XCTAssertEqual(regions.count, 24)
    }

    func testInAndOutPointsClampSampleBounds() {
        var slot = DrumSlot(samples: [Float](repeating: 0.1, count: 44100), sourceSampleRate: 44100, fileName: "kick.wav")
        slot.inPoint = 0.25  // seconds, quarter of the way in
        slot.outPoint = 0.75
        let regions = DrumPresetBuilder.regions(for: [slot], targetSampleRate: nil)
        XCTAssertEqual(regions[0].sampleStart, 11025)
        XCTAssertEqual(regions[0].sampleEnd, 33075)
    }

    func testEmptySampleSlotProducesDegenerateRegionWithoutCrashing() {
        let slot = DrumSlot(samples: [], sourceSampleRate: 44100, fileName: "empty.wav")
        let regions = DrumPresetBuilder.regions(for: [slot], targetSampleRate: nil)
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions[0].framecount, 0)
        XCTAssertEqual(regions[0].sampleStart, 0)
        XCTAssertEqual(regions[0].sampleEnd, 0)
    }

    func testZeroSourceSampleRateProducesDegenerateRegionWithoutCrashing() {
        // Dividing the sample count by a zero rate yields an infinite
        // duration, which has no representation as a frame count.
        let slot = DrumSlot(samples: [0.1, 0.2], sourceSampleRate: 0, fileName: "kick.wav")
        let regions = DrumPresetBuilder.regions(for: [slot], targetSampleRate: nil)
        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions[0].framecount, 0)
        XCTAssertEqual(regions[0].sampleStart, 0)
        XCTAssertEqual(regions[0].sampleEnd, 0)
    }

    func testBuildProducesNamedPresetFromBaseDefaults() {
        let slot = DrumSlot(samples: [Float](repeating: 0.1, count: 1000), sourceSampleRate: 44100, fileName: "kick.wav")
        let preset = DrumPresetBuilder.build(name: "my-kit", slots: [slot])
        XCTAssertEqual(preset.name, "my-kit")
        XCTAssertEqual(preset.type, "drum")
        XCTAssertEqual(preset.platform, "OP-XY")
        XCTAssertEqual(preset.regions.count, 1)
    }
}
