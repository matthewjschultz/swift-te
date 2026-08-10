import Foundation

/// Writes zip archives using the store method (method 0, no compression).
/// Audio samples don't compress well as raw PCM, so this trades a modest
/// size cost for a zero-dependency implementation — no DEFLATE needed.
public struct ZipWriter {
    private struct Entry {
        let name: String
        let data: Data
        let crc32: UInt32
        let localHeaderOffset: UInt32
    }

    private var entries: [Entry] = []
    private var cursor: UInt32 = 0

    public init() {}

    public mutating func addEntry(name: String, data: Data) {
        entries.append(Entry(name: name, data: data, crc32: CRC32.checksum(data), localHeaderOffset: cursor))
        let nameBytes = Array(name.utf8)
        cursor += UInt32(30 + nameBytes.count + data.count)
    }

    public func finalize() -> Data {
        var out = Data()
        for entry in entries {
            out.append(localFileHeader(for: entry))
            out.append(entry.data)
        }

        let centralDirectoryStart = UInt32(out.count)
        for entry in entries {
            out.append(centralDirectoryHeader(for: entry))
        }
        let centralDirectorySize = UInt32(out.count) - centralDirectoryStart

        out.append(endOfCentralDirectory(entryCount: entries.count, centralDirectorySize: centralDirectorySize, centralDirectoryOffset: centralDirectoryStart))
        return out
    }

    private func localFileHeader(for entry: Entry) -> Data {
        var d = Data()
        appendU32(&d, 0x04034b50)
        appendU16(&d, 20)               // version needed to extract
        appendU16(&d, 0)                // general purpose flags
        appendU16(&d, 0)                // compression method: store
        appendU16(&d, 0)                // mod time (unset)
        appendU16(&d, 0x21)             // mod date: 1980-01-01
        appendU32(&d, entry.crc32)
        appendU32(&d, UInt32(entry.data.count))  // compressed size
        appendU32(&d, UInt32(entry.data.count))  // uncompressed size
        let nameBytes = Array(entry.name.utf8)
        appendU16(&d, UInt16(nameBytes.count))
        appendU16(&d, 0)                // extra field length
        d.append(contentsOf: nameBytes)
        return d
    }

    private func centralDirectoryHeader(for entry: Entry) -> Data {
        var d = Data()
        appendU32(&d, 0x02014b50)
        appendU16(&d, 20)               // version made by
        appendU16(&d, 20)               // version needed to extract
        appendU16(&d, 0)                // general purpose flags
        appendU16(&d, 0)                // compression method: store
        appendU16(&d, 0)                // mod time
        appendU16(&d, 0x21)             // mod date
        appendU32(&d, entry.crc32)
        appendU32(&d, UInt32(entry.data.count))
        appendU32(&d, UInt32(entry.data.count))
        let nameBytes = Array(entry.name.utf8)
        appendU16(&d, UInt16(nameBytes.count))
        appendU16(&d, 0)                // extra field length
        appendU16(&d, 0)                // comment length
        appendU16(&d, 0)                // disk number start
        appendU16(&d, 0)                // internal file attributes
        appendU32(&d, 0)                // external file attributes
        appendU32(&d, entry.localHeaderOffset)
        d.append(contentsOf: nameBytes)
        return d
    }

    private func endOfCentralDirectory(entryCount: Int, centralDirectorySize: UInt32, centralDirectoryOffset: UInt32) -> Data {
        var d = Data()
        appendU32(&d, 0x06054b50)
        appendU16(&d, 0)                // disk number
        appendU16(&d, 0)                // disk with central directory
        appendU16(&d, UInt16(entryCount))
        appendU16(&d, UInt16(entryCount))
        appendU32(&d, centralDirectorySize)
        appendU32(&d, centralDirectoryOffset)
        appendU16(&d, 0)                // comment length
        return d
    }

    private func appendU16(_ d: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { d.append(contentsOf: $0) }
    }

    private func appendU32(_ d: inout Data, _ value: UInt32) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { d.append(contentsOf: $0) }
    }
}
