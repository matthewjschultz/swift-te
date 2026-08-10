import Foundation

public struct SynthPatch: Codable, Equatable {
    public var adsr: [Int]
    public var fxActive: Bool
    public var fxParams: [Int]
    public var fxType: String
    public var knobs: [Int]
    public var lfoActive: Bool
    public var lfoParams: [Int]
    public var lfoType: String
    public var name: String
    public var octave: Int
    public var synthVersion: Int
    public var type: String
    public var baseFreq: Double?

    enum CodingKeys: String, CodingKey {
        case adsr
        case fxActive = "fx_active"
        case fxParams = "fx_params"
        case fxType = "fx_type"
        case knobs
        case lfoActive = "lfo_active"
        case lfoParams = "lfo_params"
        case lfoType = "lfo_type"
        case name
        case octave
        case synthVersion = "synth_version"
        case type
        case baseFreq = "base_freq"
    }

    /// The "cluster" engine default teoperator's NewSynthPatch() returns.
    public static let defaultCluster = SynthPatch(
        adsr: [64, 64, 0, 64, 14336, 64, 4000, 4000],
        fxActive: true,
        fxParams: [64, -14337, 4515, 7232, 0, 0, 0, 0],
        fxType: "nitro",
        knobs: [3072, 0, 512, 3, 0, 0, 0, 0],
        lfoActive: false,
        lfoParams: [4608, 32767, 8448, 15360, 0, 0, 0, 0],
        lfoType: "value",
        name: "default",
        octave: 0,
        synthVersion: 2,
        type: "cluster",
        baseFreq: nil
    )

    /// The sampler-engine default teoperator's NewSynthSamplePatch() starts from.
    public static let defaultSampler = SynthPatch(
        adsr: [512, 10746, 32767, 10000, 4000, 64, 4000, 4000],
        fxActive: false,
        fxParams: [4480, 15544, 10788, 12104, 0, 0, 0, 0],
        fxType: "delay",
        knobs: [0, 0, 32767, 32767, 12000, 0, 0, 8304],
        lfoActive: false,
        lfoParams: [11840, 18431, 1024, 15144, 0, 0, 0, 0],
        lfoType: "random",
        name: "20150108_0251",
        octave: 0,
        synthVersion: 1,
        type: "sampler",
        baseFreq: 261.6253662109375
    )

    /// A synth patch for a single sample at the given base frequency,
    /// starting from the sampler default.
    public static func synthSample(baseFrequency: Double) -> SynthPatch {
        var patch = defaultSampler
        patch.baseFreq = baseFrequency
        return patch
    }
}
