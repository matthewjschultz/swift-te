import Foundation

public enum AIFFError: Error, Equatable {
    case notFORM
    case notAIFF
    case missingCOMMChunk
    case missingSSNDChunk
    /// A chunk declares a size that doesn't fit within the file, or is too
    /// small to hold the fields the format requires it to hold.
    case truncatedData
    case invalidChannelCount(Int)
    case invalidSampleRate
    case unsupportedBitDepth(Int)
}

/// Reads and writes standard AIFF: FORM/AIFF, COMM, SSND. Integer PCM only
/// (8/16/24/32-bit signed) — 32-bit float AIFF requires the AIFC container
/// variant, which is out of scope for v1.
public struct AIFFFile {
    public var sampleRate: Int
    public var bitDepth: Int
    public var channelCount: Int
    /// Interleaved samples, normalized to -1...1.
    public var samples: [Float]

    public init(sampleRate: Int, bitDepth: Int, channelCount: Int, samples: [Float]) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channelCount = channelCount
        self.samples = samples
    }

    public func encoded() throws -> Data {
        guard [8, 16, 24, 32].contains(bitDepth) else {
            throw AIFFError.unsupportedBitDepth(bitDepth)
        }
        guard channelCount > 0, channelCount <= Int(Int16.max) else {
            throw AIFFError.invalidChannelCount(channelCount)
        }

        let bytesPerSample = bitDepth / 8
        let frameCount = samples.count / channelCount
        let sampleDataSize = samples.count * bytesPerSample

        var commBody = Data()
        appendU16BE(&commBody, Int16(channelCount))
        appendU32BE(&commBody, UInt32(frameCount))
        appendU16BE(&commBody, Int16(bitDepth))
        commBody.append(contentsOf: Self.extended80(from: Double(sampleRate)))

        var ssndBody = Data()
        appendU32BE(&ssndBody, 0) // offset
        appendU32BE(&ssndBody, 0) // block size
        writeSamples(into: &ssndBody)

        var chunks = Data()
        chunks.append(chunk(id: "COMM", body: commBody))
        chunks.append(chunk(id: "SSND", body: ssndBody))

        var form = Data()
        form.append(contentsOf: "FORM".utf8)
        appendU32BE(&form, UInt32(4 + chunks.count))
        form.append(contentsOf: "AIFF".utf8)
        form.append(chunks)

        _ = sampleDataSize
        return form
    }

    private func chunk(id: String, body: Data) -> Data {
        var d = Data()
        d.append(contentsOf: id.utf8)
        appendU32BE(&d, UInt32(body.count))
        d.append(body)
        if body.count % 2 != 0 { d.append(0) }
        return d
    }

    private func writeSamples(into d: inout Data) {
        switch bitDepth {
        case 8:
            for s in samples {
                let v = Int((s * 127).rounded())
                d.append(UInt8(bitPattern: Int8(min(127, max(-128, v)))))
            }
        case 16:
            for s in samples {
                let v = Int((s * 32767).rounded())
                appendU16BE(&d, Int16(min(32767, max(-32768, v))))
            }
        case 24:
            for s in samples {
                let v = Int32((s * 8_388_607).rounded())
                let clamped = min(8_388_607, max(-8_388_608, v))
                d.append(UInt8(truncatingIfNeeded: clamped >> 16))
                d.append(UInt8(truncatingIfNeeded: clamped >> 8))
                d.append(UInt8(truncatingIfNeeded: clamped))
            }
        case 32:
            for s in samples {
                let v = Double(s) * 2_147_483_647.0
                let clamped = min(2_147_483_647.0, max(-2_147_483_648.0, v))
                let rounded = Int32(clamped.rounded())
                appendU32BE(&d, UInt32(bitPattern: rounded))
            }
        default:
            break
        }
    }

    public static func decode(_ data: Data) throws -> AIFFFile {
        guard data.count >= 12, data.subdata(in: 0..<4) == "FORM".data(using: .ascii) else {
            throw AIFFError.notFORM
        }
        guard data.subdata(in: 8..<12) == "AIFF".data(using: .ascii) else {
            throw AIFFError.notAIFF
        }

        guard let commRange = chunkRange(ofID: "COMM", in: data) else { throw AIFFError.missingCOMMChunk }
        guard let ssndRange = chunkRange(ofID: "SSND", in: data) else { throw AIFFError.missingSSNDChunk }

        // A COMM body is 18 bytes: channels (2), frames (4), bit depth (2),
        // sample rate (10). Both the declared size and the file's actual
        // extent have to cover that before any field is read.
        let commBodyStart = commRange.lowerBound + 8
        let commBodySize = Int(readU32BE(data, at: commRange.lowerBound + 4))
        guard commBodySize >= 18, commBodyStart + commBodySize <= data.count else {
            throw AIFFError.truncatedData
        }

        let channelCount = Int(readU16BE(data, at: commBodyStart))
        guard channelCount > 0 else { throw AIFFError.invalidChannelCount(channelCount) }
        let bitDepth = Int(readU16BE(data, at: commBodyStart + 6))
        guard [8, 16, 24, 32].contains(bitDepth) else {
            throw AIFFError.unsupportedBitDepth(bitDepth)
        }
        let sampleRateBytes = Array(data.subdata(in: (commBodyStart + 8)..<(commBodyStart + 18)))
        let sampleRateValue = extended80ToDouble(sampleRateBytes).rounded()
        guard sampleRateValue >= 1, sampleRateValue <= Double(Int32.max) else {
            throw AIFFError.invalidSampleRate
        }
        let sampleRate = Int(sampleRateValue)

        // An SSND body starts with offset (4) and block size (4); the sample
        // data is whatever the declared size covers past those.
        let ssndBodyStart = ssndRange.lowerBound + 8
        let ssndDataStart = ssndBodyStart + 8 // past offset + blockSize
        let ssndChunkSize = Int(readU32BE(data, at: ssndRange.lowerBound + 4))
        guard ssndChunkSize >= 8 else { throw AIFFError.truncatedData }
        let sampleDataEnd = ssndBodyStart + ssndChunkSize
        guard sampleDataEnd <= data.count else { throw AIFFError.truncatedData }
        let sampleData = data.subdata(in: ssndDataStart..<sampleDataEnd)
        let samples = readSamples(sampleData, bitDepth: bitDepth)

        return AIFFFile(sampleRate: sampleRate, bitDepth: bitDepth, channelCount: channelCount, samples: samples)
    }

    private static func readSamples(_ data: Data, bitDepth: Int) -> [Float] {
        var samples: [Float] = []
        let bytes = Array(data)
        switch bitDepth {
        case 8:
            samples = bytes.map { Float(Int8(bitPattern: $0)) / 127 }
        case 16:
            var i = 0
            while i + 1 < bytes.count {
                let v = Int16(bitPattern: (UInt16(bytes[i]) << 8) | UInt16(bytes[i + 1]))
                samples.append(Float(v) / 32767)
                i += 2
            }
        case 24:
            var i = 0
            while i + 2 < bytes.count {
                var raw = (Int32(bytes[i]) << 16) | (Int32(bytes[i + 1]) << 8) | Int32(bytes[i + 2])
                if raw & 0x800000 != 0 { raw |= Int32(bitPattern: 0xFF000000) }
                samples.append(Float(raw) / 8_388_607)
                i += 3
            }
        case 32:
            var i = 0
            while i + 3 < bytes.count {
                let v = (UInt32(bytes[i]) << 24) | (UInt32(bytes[i + 1]) << 16) | (UInt32(bytes[i + 2]) << 8) | UInt32(bytes[i + 3])
                samples.append(Float(Int32(bitPattern: v)) / 2_147_483_647)
                i += 4
            }
        default:
            break
        }
        return samples
    }

    /// Locates a chunk's header (starting at its 4-byte ID) within `data`.
    /// Used by TEOP1 to find the SSND chunk and splice in an APPL chunk
    /// right before it, matching how teoperator's writer works.
    public static func chunkRange(ofID id: String, in data: Data) -> Range<Data.Index>? {
        var offset = 12
        while offset + 8 <= data.count {
            let chunkID = String(data: data.subdata(in: offset..<(offset + 4)), encoding: .ascii) ?? ""
            let chunkSize = Int(readU32BE(data, at: offset + 4))
            if chunkID == id {
                return offset..<(offset + 8 + chunkSize)
            }
            offset += 8 + chunkSize + (chunkSize % 2)
        }
        return nil
    }

    private static func readU16BE(_ data: Data, at offset: Int) -> UInt16 {
        (UInt16(data[data.startIndex + offset]) << 8) | UInt16(data[data.startIndex + offset + 1])
    }

    private static func readU32BE(_ data: Data, at offset: Int) -> UInt32 {
        (UInt32(data[data.startIndex + offset]) << 24) | (UInt32(data[data.startIndex + offset + 1]) << 16)
            | (UInt32(data[data.startIndex + offset + 2]) << 8) | UInt32(data[data.startIndex + offset + 3])
    }

    private func appendU16BE(_ d: inout Data, _ value: Int16) {
        var x = value.bigEndian
        withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
    }

    private func appendU32BE(_ d: inout Data, _ value: UInt32) {
        var x = value.bigEndian
        withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
    }

    /// Standard IEEE 754 80-bit extended float encoding, used by AIFF's
    /// COMM chunk to store the sample rate.
    static func extended80(from value: Double) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 10)
        guard value != 0 else { return bytes }
        let sign: UInt16 = value < 0 ? 0x8000 : 0
        var v = abs(value)
        var exponent = 0
        while v >= 2 { v /= 2; exponent += 1 }
        while v < 1 { v *= 2; exponent -= 1 }
        let biasedExponent = UInt16(exponent + 16383)
        let mantissa = UInt64((v - 1) * 9_223_372_036_854_775_808.0) | 0x8000000000000000
        let expWithSign = sign | biasedExponent
        bytes[0] = UInt8(expWithSign >> 8)
        bytes[1] = UInt8(expWithSign & 0xFF)
        for i in 0..<8 {
            bytes[2 + i] = UInt8((mantissa >> (8 * (7 - i))) & 0xFF)
        }
        return bytes
    }

    static func extended80ToDouble(_ bytes: [UInt8]) -> Double {
        guard bytes.count == 10 else { return 0 }
        let expWithSign = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        let sign: Double = (expWithSign & 0x8000) != 0 ? -1 : 1
        let exponent = Int(expWithSign & 0x7FFF) - 16383
        var mantissa: UInt64 = 0
        for i in 0..<8 { mantissa = (mantissa << 8) | UInt64(bytes[2 + i]) }
        let fraction = Double(mantissa) / 9_223_372_036_854_775_808.0
        return sign * fraction * pow(2.0, Double(exponent))
    }
}
