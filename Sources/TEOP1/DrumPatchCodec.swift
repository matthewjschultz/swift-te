import Foundation
import TECore

public enum DrumPatchCodecError: Error, Equatable {
    case missingAPPLChunk
    case malformedJSON
}

public enum DrumPatchCodec {

    /// Encodes `patch`'s metadata into an AIFF's `APPL`/`op-1` chunk.
    /// Clamps slot bounds first, matching teoperator's DrumPatch.Save.
    /// Pads the file so its total size is a multiple of 4 bytes, matching
    /// that path exactly (teoperator's drum and synth paths pad to
    /// different multiples — 4 and 2 respectively — this preserves both).
    public static func encode(_ patch: DrumPatch, samples: [Float], sampleRate: Int) throws -> Data {
        var clamped = patch
        clamped.clampSlotBounds()
        let base = try AIFFFile(sampleRate: sampleRate, bitDepth: 16, channelCount: 1, samples: samples).encoded()
        // DrumPatch is all-integer today, so `encode` can't currently fail —
        // but propagate rather than swallow, so adding a floating-point field
        // later surfaces the failure instead of writing a garbage chunk.
        let jsonData = try JSONEncoder().encode(clamped)
        return try SynthPatchCodec.spliceAPPLChunk(into: base, jsonData: jsonData, paddingMultiple: 4)
    }

    public static func decode(_ data: Data) throws -> DrumPatch {
        let jsonData: Data
        do {
            jsonData = try SynthPatchCodec.extractOP1JSON(from: data)
        } catch {
            throw DrumPatchCodecError.missingAPPLChunk
        }
        do {
            return try JSONDecoder().decode(DrumPatch.self, from: jsonData)
        } catch {
            throw DrumPatchCodecError.malformedJSON
        }
    }
}
