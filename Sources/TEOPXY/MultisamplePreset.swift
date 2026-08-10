import Foundation

private let loopEndPadding = 5

public struct MultisampleRegion: Codable, Equatable {
    public var framecount: Int
    public var gain: Double
    public var hikey: Int
    public var lokey: Int
    public var loopCrossfade: Int
    public var loopEnd: Int
    public var loopOnRelease: Bool
    public var loopEnabled: Bool
    public var loopStart: Int
    public var pitchKeycenter: Int
    public var reverse: Bool
    public var sample: String
    public var sampleEnd: Int
    public var sampleStart: Int
    public var tune: Int

    enum CodingKeys: String, CodingKey {
        case framecount, gain, hikey, lokey
        case loopCrossfade = "loop.crossfade"
        case loopEnd = "loop.end"
        case loopOnRelease = "loop.onrelease"
        case loopEnabled = "loop.enabled"
        case loopStart = "loop.start"
        case pitchKeycenter = "pitch.keycenter"
        case reverse, sample
        case sampleEnd = "sample.end"
        case sampleStart = "sample.start"
        case tune
    }
}

public struct MultisamplePreset: Codable, Equatable {
    public var name: String
    public var engine: Engine
    public var envelope: Envelope
    public var fx: EffectBlock
    public var lfo: EffectBlock
    public var octave: Int
    public var platform: String
    public var regions: [MultisampleRegion]
    public var type: String
    public var version: Int

    /// Ported from op-patchstudio's baseMultisampleJson.ts.
    public static let base = MultisamplePreset(
        name: "",
        engine: Engine(
            bendrange: 13653,
            highpass: 0,
            modulation: Modulation(
                aftertouch: ModulationTarget(amount: 30719, target: 4096),
                modwheel: ModulationTarget(amount: 32767, target: 10240),
                pitchbend: ModulationTarget(amount: 16383, target: 0),
                velocity: ModulationTarget(amount: 16383, target: 0)
            ),
            params: Array(repeating: 16384, count: 8),
            playmode: "poly",
            portamentoAmount: 0,
            portamentoType: 32767,
            transpose: 0,
            tuningRoot: 0,
            tuningScale: 0,
            velocitySensitivity: 10240,
            volume: 16466,
            width: 3072
        ),
        envelope: Envelope(
            amp: ADSR(attack: 0, decay: 20295, release: 16383, sustain: 14989),
            filter: ADSR(attack: 0, decay: 16895, release: 19968, sustain: 16896)
        ),
        fx: EffectBlock(active: false, params: [19661, 0, 7391, 24063, 0, 32767, 0, 0], type: "svf"),
        lfo: EffectBlock(active: false, params: [19024, 32255, 4048, 17408, 0, 0, 0, 0], type: "element"),
        octave: 0,
        platform: "OP-XY",
        regions: [],
        type: "multisampler",
        version: 4
    )
}

/// One multisample zone. Zones must be passed to the builder already
/// sorted by `rootNote` ascending — key ranges are derived from that order,
/// matching op-patchstudio's sort-then-split region generation.
public struct MultisampleZone {
    public var samples: [Float]
    public var sourceSampleRate: Int
    public var fileName: String
    public var rootNote: Int
    public var inPoint: Double?
    public var outPoint: Double?
    public var loopStart: Double?  // seconds
    public var loopEnd: Double?    // seconds

    public init(samples: [Float], sourceSampleRate: Int, fileName: String, rootNote: Int, inPoint: Double? = nil, outPoint: Double? = nil, loopStart: Double? = nil, loopEnd: Double? = nil) {
        self.samples = samples
        self.sourceSampleRate = sourceSampleRate
        self.fileName = fileName
        self.rootNote = rootNote
        self.inPoint = inPoint
        self.outPoint = outPoint
        self.loopStart = loopStart
        self.loopEnd = loopEnd
    }
}

public enum MultisamplePresetBuilder {
    private static let maxZones = 24

    public static func build(
        name: String,
        zones: [MultisampleZone],
        targetSampleRate: Int? = nil,
        gain: Double = 0,
        loopEnabled: Bool = false,
        loopOnRelease: Bool = false,
        cutAtLoopEnd: Bool = false
    ) -> MultisamplePreset {
        var preset = MultisamplePreset.base
        preset.name = name

        let capped = Array(zones.prefix(maxZones))
        var regions: [MultisampleRegion] = []
        var lastKey = 0
        for zone in capped {
            regions.append(region(for: zone, lowKey: lastKey, targetSampleRate: targetSampleRate, gain: gain, loopEnabled: loopEnabled, loopOnRelease: loopOnRelease, cutAtLoopEnd: cutAtLoopEnd))
            lastKey = zone.rootNote + 1
        }
        if !regions.isEmpty {
            regions[regions.count - 1].hikey = 127
        }
        preset.regions = regions
        return preset
    }

    private static func region(for zone: MultisampleZone, lowKey: Int, targetSampleRate: Int?, gain: Double, loopEnabled: Bool, loopOnRelease: Bool, cutAtLoopEnd: Bool) -> MultisampleRegion {
        guard !zone.samples.isEmpty else {
            return MultisampleRegion(
                framecount: 0,
                gain: gain,
                hikey: zone.rootNote,
                lokey: lowKey,
                loopCrossfade: 0,
                loopEnd: 0,
                loopOnRelease: loopOnRelease,
                loopEnabled: loopEnabled,
                loopStart: 0,
                pitchKeycenter: zone.rootNote,
                reverse: false,
                sample: zone.fileName,
                sampleEnd: 0,
                sampleStart: 0,
                tune: 0
            )
        }

        let originalSampleRate = zone.sourceSampleRate
        let duration = Double(zone.samples.count) / Double(originalSampleRate)
        let effectiveSampleRate = targetSampleRate ?? originalSampleRate
        let framecount = Int((duration * Double(effectiveSampleRate)).rounded(.down))
        let originalFramecount = zone.samples.count

        let loopStartSeconds = zone.loopStart ?? (duration * 0.1)
        let loopEndSeconds = zone.loopEnd ?? (duration * 0.9)
        let loopStartFrames = clamp(Int((loopStartSeconds * Double(originalSampleRate)).rounded(.down)), 0, originalFramecount - 1)
        let loopEndFrames = clamp(Int((loopEndSeconds * Double(originalSampleRate)).rounded(.down)), loopStartFrames + 1, originalFramecount)

        let scaleFactor = Double(effectiveSampleRate) / Double(originalSampleRate)
        let scaledLoopStart = Int((Double(loopStartFrames) * scaleFactor).rounded(.down))
        let scaledLoopEnd = Int((Double(loopEndFrames) * scaleFactor).rounded(.down))

        let inPointSeconds = zone.inPoint ?? 0
        let outPointSeconds = zone.outPoint ?? duration
        let sampleStart = clamp(Int((Double(framecount) * inPointSeconds / duration).rounded(.down)), 0, framecount - 1)
        let sampleEnd = clamp(Int((Double(framecount) * outPointSeconds / duration).rounded(.down)), sampleStart + 1, framecount)

        let actualFramecount = cutAtLoopEnd ? scaledLoopEnd + loopEndPadding : framecount

        return MultisampleRegion(
            framecount: actualFramecount,
            gain: gain,
            hikey: zone.rootNote,
            lokey: lowKey,
            loopCrossfade: 0,
            loopEnd: scaledLoopEnd,
            loopOnRelease: loopOnRelease,
            loopEnabled: loopEnabled,
            loopStart: scaledLoopStart,
            pitchKeycenter: zone.rootNote,
            reverse: false,
            sample: zone.fileName,
            sampleEnd: cutAtLoopEnd ? actualFramecount : sampleEnd,
            sampleStart: sampleStart,
            tune: 0
        )
    }

    private static func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
