import Foundation

public enum WAVError: Error, Equatable {
    case notRIFF
    case notWAVE
    case missingFmtChunk
    case missingDataChunk
    case unsupportedBitDepth(Int)
}

/// Reads and writes PCM WAV, including the `smpl` chunk op-patchstudio uses
/// to carry root note and loop points.
public struct WAVFile {
    public var sampleRate: Int
    public var bitDepth: Int
    public var channelCount: Int
    /// Interleaved samples, normalized to -1...1.
    public var samples: [Float]
    public var rootNote: Int?
    public var loopStart: Int?
    public var loopEnd: Int?

    public init(sampleRate: Int, bitDepth: Int, channelCount: Int, samples: [Float], rootNote: Int? = nil, loopStart: Int? = nil, loopEnd: Int? = nil) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channelCount = channelCount
        self.samples = samples
        self.rootNote = rootNote
        self.loopStart = loopStart
        self.loopEnd = loopEnd
    }

    public func encoded() throws -> Data {
        guard [8, 16, 24, 32].contains(bitDepth) else {
            throw WAVError.unsupportedBitDepth(bitDepth)
        }

        let bytesPerSample = bitDepth / 8
        let dataSize = samples.count * bytesPerSample
        let hasSMPL = rootNote != nil || loopStart != nil || loopEnd != nil
        let smplChunkSize = 60

        var d = Data()
        func tag(_ s: String) { d.append(contentsOf: s.utf8) }
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }

        let byteRate = sampleRate * channelCount * bytesPerSample
        let blockAlign = channelCount * bytesPerSample
        let riffSize = 4 + (8 + 16) + (hasSMPL ? (8 + smplChunkSize) : 0) + (8 + dataSize)

        tag("RIFF"); u32(UInt32(riffSize)); tag("WAVE")

        tag("fmt "); u32(16)
        u16(1) // PCM
        u16(UInt16(channelCount))
        u32(UInt32(sampleRate))
        u32(UInt32(byteRate))
        u16(UInt16(blockAlign))
        u16(UInt16(bitDepth))

        if hasSMPL {
            tag("smpl"); u32(UInt32(smplChunkSize))
            u32(0)                                  // manufacturer
            u32(0)                                  // product
            u32(UInt32(1_000_000_000 / sampleRate))  // sample period, nanoseconds
            u32(rootNote.map(UInt32.init) ?? 0xFFFFFFFF)  // MIDI unity note (sentinel 0xFFFFFFFF for nil)
            u32(0)                                  // MIDI pitch fraction
            u32(0)                                  // SMPTE format
            u32(0)                                  // SMPTE offset
            u32(1)                                  // number of loops
            u32(0)                                  // sampler data
            u32(0)                                  // cue point ID
            u32(0)                                  // loop type: forward
            u32(UInt32(max(0, (loopStart ?? 0) - 1)))
            u32(UInt32(max(0, (loopEnd ?? (samples.count - 1)) - 1)))
            u32(0)                                  // fraction
            u32(0)                                  // play count
        }

        tag("data"); u32(UInt32(dataSize))
        writeSamples(into: &d)

        return d
    }

    private func writeSamples(into d: inout Data) {
        switch bitDepth {
        case 8:
            for s in samples {
                let v = Int((s * 127).rounded()) + 128
                d.append(UInt8(min(255, max(0, v))))
            }
        case 16:
            for s in samples {
                let v = Int((s * 32767).rounded())
                var x = Int16(min(32767, max(-32768, v))).littleEndian
                withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
            }
        case 24:
            for s in samples {
                let v = Int32((s * 8_388_607).rounded())
                let clamped = min(8_388_607, max(-8_388_608, v))
                d.append(UInt8(truncatingIfNeeded: clamped))
                d.append(UInt8(truncatingIfNeeded: clamped >> 8))
                d.append(UInt8(truncatingIfNeeded: clamped >> 16))
            }
        case 32:
            for s in samples {
                let v = (Double(s) * 2_147_483_647).rounded()
                let clamped = min(2_147_483_647.0, max(-2_147_483_648.0, v))
                var x = Int32(clamped).littleEndian
                withUnsafeBytes(of: &x) { d.append(contentsOf: $0) }
            }
        default:
            break
        }
    }

    public static func decode(_ data: Data) throws -> WAVFile {
        guard data.count >= 12, data.subdata(in: 0..<4) == "RIFF".data(using: .ascii) else {
            throw WAVError.notRIFF
        }
        guard data.subdata(in: 8..<12) == "WAVE".data(using: .ascii) else {
            throw WAVError.notWAVE
        }

        var offset = 12
        var channelCount = 1
        var sampleRate = 44100
        var bitDepth = 16
        var samples: [Float] = []
        var rootNote: Int?
        var loopStart: Int?
        var loopEnd: Int?
        var foundFmt = false
        var foundData = false

        func u32(_ at: Int) -> UInt32 {
            data.subdata(in: at..<(at + 4)).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
        }
        func u16(_ at: Int) -> UInt16 {
            data.subdata(in: at..<(at + 2)).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
        }

        while offset + 8 <= data.count {
            let chunkID = String(data: data.subdata(in: offset..<(offset + 4)), encoding: .ascii) ?? ""
            let chunkSize = Int(u32(offset + 4))
            let chunkStart = offset + 8
            guard chunkStart + chunkSize <= data.count else { break }

            if chunkID == "fmt " {
                foundFmt = true
                channelCount = Int(u16(chunkStart + 2))
                sampleRate = Int(u32(chunkStart + 4))
                bitDepth = Int(u16(chunkStart + 14))
            } else if chunkID == "smpl" {
                let midiUnityNote = u32(chunkStart + 12)
                rootNote = midiUnityNote == 0xFFFFFFFF ? nil : Int(midiUnityNote)
                loopStart = Int(u32(chunkStart + 44)) + 1
                loopEnd = Int(u32(chunkStart + 48)) + 1
            } else if chunkID == "data" {
                foundData = true
                samples = Self.readSamples(data.subdata(in: chunkStart..<(chunkStart + chunkSize)), bitDepth: bitDepth)
            }

            offset = chunkStart + chunkSize + (chunkSize % 2)
        }

        guard foundFmt else { throw WAVError.missingFmtChunk }
        guard foundData else { throw WAVError.missingDataChunk }
        guard [8, 16, 24, 32].contains(bitDepth) else {
            throw WAVError.unsupportedBitDepth(bitDepth)
        }

        return WAVFile(sampleRate: sampleRate, bitDepth: bitDepth, channelCount: channelCount, samples: samples, rootNote: rootNote, loopStart: loopStart, loopEnd: loopEnd)
    }

    private static func readSamples(_ data: Data, bitDepth: Int) -> [Float] {
        var samples: [Float] = []
        switch bitDepth {
        case 8:
            samples = data.map { (Float(Int($0)) - 128) / 127 }
        case 16:
            var i = 0
            while i + 1 < data.count {
                let v = data.subdata(in: i..<(i + 2)).withUnsafeBytes { $0.load(as: Int16.self) }.littleEndian
                samples.append(Float(v) / 32767)
                i += 2
            }
        case 24:
            var i = 0
            while i + 2 < data.count {
                var raw = Int32(data[data.startIndex + i]) | (Int32(data[data.startIndex + i + 1]) << 8) | (Int32(data[data.startIndex + i + 2]) << 16)
                if raw & 0x800000 != 0 { raw |= Int32(bitPattern: 0xFF000000) }
                samples.append(Float(raw) / 8_388_607)
                i += 3
            }
        case 32:
            var i = 0
            while i + 3 < data.count {
                let v = data.subdata(in: i..<(i + 4)).withUnsafeBytes { $0.load(as: Int32.self) }.littleEndian
                samples.append(Float(v) / 2_147_483_647)
                i += 4
            }
        default:
            break
        }
        return samples
    }
}
