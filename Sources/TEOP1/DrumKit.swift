import Foundation

public struct DrumKitResult {
    public let patch: DrumPatch
    /// The merged mono samples the patch's start/end slots reference.
    public let samples: [Float]
    public let sampleRate: Int
}

public enum DrumKit {

    private static let maxSlots = 24

    /// Splices at file boundaries — one slot per clip, in order given.
    public static func build(from clips: [[Float]], sampleRate: Int) -> DrumKitResult {
        let clipped = Array(clips.prefix(maxSlots))
        var merged: [Float] = []
        var boundaries: [(start: Int, end: Int)] = []
        for clip in clipped {
            let start = merged.count
            merged.append(contentsOf: clip)
            boundaries.append((start: start, end: merged.count))
        }
        return DrumKitResult(patch: patch(from: boundaries, sampleRate: sampleRate), samples: merged, sampleRate: sampleRate)
    }

    /// Splices one long buffer using the given detection mode.
    public static func build(splicing samples: [Float], sampleRate: Int, mode: SpliceMode) -> DrumKitResult {
        let ranges = DrumSplicer.splice(samples, sampleRate: sampleRate, mode: mode).prefix(maxSlots)
        let boundaries = ranges.map { (start: $0.start, end: $0.end) }
        return DrumKitResult(patch: patch(from: boundaries, sampleRate: sampleRate), samples: samples, sampleRate: sampleRate)
    }

    private static func patch(from boundaries: [(start: Int, end: Int)], sampleRate: Int) -> DrumPatch {
        var patch = DrumPatch.defaultPatch
        for (index, bounds) in boundaries.enumerated() where index < maxSlots {
            let startSeconds = Double(bounds.start) / Double(sampleRate)
            let endSeconds = Double(bounds.end) / Double(sampleRate)
            patch.start[index] = OP1.frameOffset(seconds: startSeconds)
            patch.end[index] = OP1.frameOffset(seconds: endSeconds)
        }
        patch.clampSlotBounds()
        return patch
    }
}
