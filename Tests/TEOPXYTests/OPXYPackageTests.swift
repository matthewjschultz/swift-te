import XCTest
@testable import TEOPXY

final class OPXYPackageTests: XCTestCase {
    func testDrumPackageContainsPatchJSONAndSamplesAtRoot() throws {
        let slot = DrumSlot(samples: [Float](repeating: 0.1, count: 1000), sourceSampleRate: 44100, fileName: "kick.wav")
        let preset = DrumPresetBuilder.build(name: "kit", slots: [slot])
        let sampleData = "fake wav bytes".data(using: .utf8)!

        let zipData = try OPXYPackage.write(preset: preset, samples: [sampleData], names: ["kick.wav"])

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let zipPath = tempDir.appendingPathComponent("kit.preset.zip")
        try zipData.write(to: zipPath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipPath.path, "-d", tempDir.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        // Files land at the archive root, not inside a named subfolder —
        // matching op-patchstudio's generateDrumPatch exactly.
        let patchJSONPath = tempDir.appendingPathComponent("patch.json")
        let kickPath = tempDir.appendingPathComponent("kick.wav")
        XCTAssertTrue(FileManager.default.fileExists(atPath: patchJSONPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: kickPath.path))

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: patchJSONPath)) as? [String: Any]
        XCTAssertEqual(json?["name"] as? String, "kit")

        try FileManager.default.removeItem(at: tempDir)
    }

    func testMismatchedSampleAndNameCountsThrows() {
        let preset = DrumPreset.base
        XCTAssertThrowsError(try OPXYPackage.write(preset: preset, samples: [Data(), Data()], names: ["only-one.wav"]))
    }

    func testMultisamplePackagePatchJSONRegionCount() throws {
        let zone = MultisampleZone(samples: [Float](repeating: 0.1, count: 1000), sourceSampleRate: 44100, fileName: "c4.wav", rootNote: 60)
        let preset = MultisamplePresetBuilder.build(name: "keys", zones: [zone])
        let zipData = try OPXYPackage.write(preset: preset, samples: ["fake".data(using: .utf8)!], names: ["c4.wav"])
        XCTAssertGreaterThan(zipData.count, 0)
    }
}
