import XCTest
@testable import TECore

final class ZipWriterTests: XCTestCase {
    func testSingleEntryHasCorrectSignatures() {
        var writer = ZipWriter()
        writer.addEntry(name: "hello.txt", data: "hello world".data(using: .utf8)!)
        let zipped = writer.finalize()

        // Local file header signature: PK\x03\x04
        XCTAssertEqual(zipped.prefix(4), Data([0x50, 0x4B, 0x03, 0x04]))
        // End of central directory signature: PK\x05\x06, must be present somewhere near the end
        let eocdSignature = Data([0x50, 0x4B, 0x05, 0x06])
        XCTAssertTrue(zipped.suffix(64).range(of: eocdSignature) != nil)
    }

    func testMultipleEntriesRoundTripThroughUnzip() throws {
        var writer = ZipWriter()
        writer.addEntry(name: "a.txt", data: "first".data(using: .utf8)!)
        writer.addEntry(name: "b.txt", data: "second".data(using: .utf8)!)
        let zipped = writer.finalize()

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let zipPath = tempDir.appendingPathComponent("test.zip")
        try zipped.write(to: zipPath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipPath.path, "-d", tempDir.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let aContents = try String(contentsOf: tempDir.appendingPathComponent("a.txt"), encoding: .utf8)
        let bContents = try String(contentsOf: tempDir.appendingPathComponent("b.txt"), encoding: .utf8)
        XCTAssertEqual(aContents, "first")
        XCTAssertEqual(bContents, "second")

        try FileManager.default.removeItem(at: tempDir)
    }
}
