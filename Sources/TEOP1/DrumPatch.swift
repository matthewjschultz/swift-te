import Foundation

public struct DrumPatch: Codable, Equatable {
    public var drumVersion: Int
    public var dynaEnv: [Int64]
    public var end: [Int64]
    public var fxActive: Bool
    public var fxParams: [Int64]
    public var fxType: String
    public var lfoActive: Bool
    public var lfoParams: [Int64]
    public var lfoType: String
    public var name: String
    public var octave: Int64
    public var pitch: [Int64]
    public var playmode: [Int64]
    public var reverse: [Int64]
    public var start: [Int64]
    public var type: String
    public var volume: [Int64]

    enum CodingKeys: String, CodingKey {
        case drumVersion = "drum_version"
        case dynaEnv = "dyna_env"
        case end
        case fxActive = "fx_active"
        case fxParams = "fx_params"
        case fxType = "fx_type"
        case lfoActive = "lfo_active"
        case lfoParams = "lfo_params"
        case lfoType = "lfo_type"
        case name
        case octave
        case pitch
        case playmode
        case reverse
        case start
        case type
        case volume
    }

    /// All 24 slots must stay within [0, OP1.maxEndPoint]. Called before
    /// encoding, matching teoperator's own bounds check in DrumPatch.Save.
    public mutating func clampSlotBounds() {
        for i in end.indices { end[i] = min(max(end[i], 0), OP1.maxEndPoint) }
        for i in start.indices { start[i] = min(max(start[i], 0), OP1.maxEndPoint) }
    }

    public static let defaultPatch = DrumPatch(
        drumVersion: 2,
        dynaEnv: [0, 8192, 0, 8192, 0, 0, 0, 0],
        end: [97643143, 165163892, 211907777, 282025634, 313446583, 372916297, 413167412, 454132733, 478541489, 492549640, 582028126, 642634075, 642634075, 642634075, 642634075, 642634075, 642634075, 642634075, 642634075, 642634075, 642634075, 642634075, 642634075, 2032606256],
        fxActive: false,
        fxParams: [8000, 8000, 8000, 8000, 8000, 8000, 8000, 8000],
        fxType: "delay",
        lfoActive: false,
        lfoParams: [16000, 16000, 16000, 16000, 0, 0, 0, 0],
        lfoType: "tremolo",
        name: "boombap1",
        octave: 0,
        pitch: Array(repeating: 0, count: 24),
        playmode: Array(repeating: 8192, count: 24),
        reverse: Array(repeating: 8192, count: 24),
        start: [0, 97647201, 165167950, 211911835, 282029692, 313450641, 372920355, 413171470, 454136790, 478545547, 492553698, 582032184, 582032184, 582032184, 582032184, 582032184, 582032184, 582032184, 582032184, 582032184, 582032184, 582032184, 582032184, 642638133],
        type: "drum",
        volume: Array(repeating: 8192, count: 24)
    )
}
