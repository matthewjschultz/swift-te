import Foundation

public struct DrumRegion: Codable, Equatable {
    public var fadeIn: Double
    public var fadeOut: Double
    public var framecount: Int
    public var hikey: Int
    public var lokey: Int
    public var pan: Double
    public var pitchKeycenter: Int
    public var playmode: String
    public var reverse: Bool
    public var sample: String
    public var transpose: Int
    public var tune: Int
    public var gain: Double
    public var sampleStart: Int
    public var sampleEnd: Int

    enum CodingKeys: String, CodingKey {
        case fadeIn = "fade.in"
        case fadeOut = "fade.out"
        case framecount, hikey, lokey, pan
        case pitchKeycenter = "pitch.keycenter"
        case playmode, reverse, sample, transpose, tune, gain
        case sampleStart = "sample.start"
        case sampleEnd = "sample.end"
    }
}

public struct DrumPreset: Codable, Equatable {
    public var name: String
    public var engine: Engine
    public var envelope: Envelope
    public var fx: EffectBlock
    public var lfo: EffectBlock
    public var octave: Int
    public var platform: String
    public var regions: [DrumRegion]
    public var type: String
    public var version: Int

    /// Ported from op-patchstudio's baseDrumJson.ts.
    public static let base = DrumPreset(
        name: "",
        engine: Engine(
            bendrange: 8191,
            highpass: 0,
            modulation: Modulation(
                aftertouch: ModulationTarget(amount: 16383, target: 0),
                modwheel: ModulationTarget(amount: 16383, target: 0),
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
            velocitySensitivity: 19660,
            volume: 18348,
            width: 0
        ),
        envelope: Envelope(
            amp: ADSR(attack: 0, decay: 0, release: 1000, sustain: 32767),
            filter: ADSR(attack: 0, decay: 3276, release: 23757, sustain: 983)
        ),
        fx: EffectBlock(active: false, params: [22014, 0, 30285, 11880, 0, 32767, 0, 0], type: "ladder"),
        lfo: EffectBlock(active: false, params: [20309, 5679, 19114, 15807, 0, 0, 0, 12287], type: "random"),
        octave: 0,
        platform: "OP-XY",
        regions: [],
        type: "drum",
        version: 4
    )
}

/// One drum slot's audio and per-sample settings. Slots are assigned MIDI
/// notes F#3 (53) upward in array order, matching op-patchstudio's
/// assignedKey-sorted region generation — order the array by target drum
/// key before calling build.
public struct DrumSlot {
    public var samples: [Float]
    public var sourceSampleRate: Int
    public var fileName: String
    public var inPoint: Double?
    public var outPoint: Double?
    public var pan: Double
    public var gain: Double
    public var transpose: Int
    public var reverse: Bool
    public var playmode: String

    public init(samples: [Float], sourceSampleRate: Int, fileName: String, inPoint: Double? = nil, outPoint: Double? = nil, pan: Double = 0, gain: Double = 0, transpose: Int = 0, reverse: Bool = false, playmode: String = "oneshot") {
        self.samples = samples
        self.sourceSampleRate = sourceSampleRate
        self.fileName = fileName
        self.inPoint = inPoint
        self.outPoint = outPoint
        self.pan = pan
        self.gain = gain
        self.transpose = transpose
        self.reverse = reverse
        self.playmode = playmode
    }
}

public enum DrumPresetBuilder {
    public static let firstMIDINote = 53
    private static let maxSlots = 24

    public static func regions(for slots: [DrumSlot], targetSampleRate: Int?) -> [DrumRegion] {
        let capped = Array(slots.prefix(maxSlots))
        return capped.enumerated().map { index, slot in
            region(for: slot, midiNote: firstMIDINote + index, targetSampleRate: targetSampleRate)
        }
    }

    private static func region(for slot: DrumSlot, midiNote: Int, targetSampleRate: Int?) -> DrumRegion {
        let framecount: Int
        let sampleStart: Int
        let sampleEnd: Int
        if slot.samples.isEmpty || slot.sourceSampleRate <= 0 {
            framecount = 0
            sampleStart = 0
            sampleEnd = 0
        } else {
            let duration = Double(slot.samples.count) / Double(slot.sourceSampleRate)
            let effectiveSampleRate = targetSampleRate ?? slot.sourceSampleRate
            framecount = Int((duration * Double(effectiveSampleRate)).rounded(.down))

            let inPointSeconds = slot.inPoint ?? 0
            let outPointSeconds = slot.outPoint ?? duration
            sampleStart = clamp(Int((Double(framecount) * inPointSeconds / duration).rounded(.down)), 0, framecount - 1)
            sampleEnd = clamp(Int((Double(framecount) * outPointSeconds / duration).rounded(.down)), sampleStart + 1, framecount)
        }

        return DrumRegion(
            fadeIn: 0,
            fadeOut: 0,
            framecount: framecount,
            hikey: midiNote,
            lokey: midiNote,
            pan: slot.pan,
            pitchKeycenter: 60,
            playmode: slot.playmode,
            reverse: slot.reverse,
            sample: slot.fileName,
            transpose: slot.transpose,
            tune: 0,
            gain: slot.gain,
            sampleStart: sampleStart,
            sampleEnd: sampleEnd
        )
    }

    public static func build(name: String, slots: [DrumSlot], targetSampleRate: Int? = nil) -> DrumPreset {
        var preset = DrumPreset.base
        preset.name = name
        preset.regions = regions(for: slots, targetSampleRate: targetSampleRate)
        return preset
    }

    private static func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
