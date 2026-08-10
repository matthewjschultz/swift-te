import Foundation
import TECore

public enum SynthPatchCodecError: Error, Equatable {
    case missingSSNDChunk
    case missingAPPLChunk
    case malformedJSON
}

public enum SynthPatchCodec {

    /// Encodes `patch`'s metadata into an AIFF's `APPL`/`op-1` chunk,
    /// inserted right before the SSND chunk — the same splice point
    /// teoperator's SynthPatch.SaveSynth uses. Pads the file so its total
    /// size is a multiple of 2 bytes, matching that path exactly.
    public static func encode(_ patch: SynthPatch, samples: [Float], sampleRate: Int) throws -> Data {
        let base = try AIFFFile(sampleRate: sampleRate, bitDepth: 16, channelCount: 1, samples: samples).encoded()
        let jsonData = (try? JSONEncoder().encode(patch)) ?? Data()
        return spliceAPPLChunk(into: base, jsonData: jsonData, paddingMultiple: 2)
    }

    public static func decode(_ data: Data) throws -> SynthPatch {
        let jsonData = try extractOP1JSON(from: data)
        do {
            return try JSONDecoder().decode(SynthPatch.self, from: jsonData)
        } catch {
            throw SynthPatchCodecError.malformedJSON
        }
    }

    static func spliceAPPLChunk(into aiffData: Data, jsonData: Data, paddingMultiple: Int) -> Data {
        guard let ssndRange = AIFFFile.chunkRange(ofID: "SSND", in: aiffData) else {
            return aiffData
        }
        let ssndOffset = ssndRange.lowerBound

        var filler: [UInt8] = [10]
        while true {
            var body = aiffData.subdata(in: 0..<ssndOffset)
            body.append(contentsOf: "APPL".utf8)
            var sizeField = UInt32(4 + filler.count + jsonData.count).bigEndian
            withUnsafeBytes(of: &sizeField) { body.append(contentsOf: $0) }
            body.append(contentsOf: "op-1".utf8)
            body.append(jsonData)
            body.append(contentsOf: filler)
            body.append(aiffData.subdata(in: ssndOffset..<aiffData.count))

            let totalSize = body.count - 8
            if totalSize % paddingMultiple == 0 {
                var totalSizeField = UInt32(totalSize).bigEndian
                var result = body.subdata(in: 0..<4)
                withUnsafeBytes(of: &totalSizeField) { result.append(contentsOf: $0) }
                result.append(body.subdata(in: 8..<body.count))
                return result
            }
            filler.append(30)
        }
    }

    static func extractOP1JSON(from data: Data) throws -> Data {
        guard let applMarker = data.range(of: "op-1".data(using: .ascii)!) else {
            throw SynthPatchCodecError.missingAPPLChunk
        }
        let jsonStart = applMarker.upperBound
        guard let jsonEnd = matchingBraceEnd(in: data, openBraceAt: jsonStart) else {
            throw SynthPatchCodecError.malformedJSON
        }
        return data.subdata(in: jsonStart..<jsonEnd)
    }

    /// Finds the index just past the closing brace that matches the first
    /// `{` at or after `start`, counting nested braces. String-aware, so
    /// braces inside quoted JSON string values (e.g. a patch name like
    /// `"warm{bass}"`) don't throw off the depth count.
    static func matchingBraceEnd(in data: Data, openBraceAt start: Data.Index) -> Data.Index? {
        var depth = 0
        var index = start
        var sawOpen = false
        var insideString = false
        var escaped = false
        while index < data.endIndex {
            let byte = data[index]
            if insideString {
                if escaped {
                    escaped = false
                } else if byte == UInt8(ascii: "\\") {
                    escaped = true
                } else if byte == UInt8(ascii: "\"") {
                    insideString = false
                }
            } else {
                if byte == UInt8(ascii: "\"") {
                    insideString = true
                } else if byte == UInt8(ascii: "{") {
                    depth += 1
                    sawOpen = true
                } else if byte == UInt8(ascii: "}") {
                    depth -= 1
                    if sawOpen && depth == 0 {
                        return data.index(after: index)
                    }
                }
            }
            index = data.index(after: index)
        }
        return nil
    }
}
