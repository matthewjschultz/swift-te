import Foundation

public struct ModulationTarget: Codable, Equatable {
    public var amount: Int
    public var target: Int

    public init(amount: Int, target: Int) {
        self.amount = amount
        self.target = target
    }
}

public struct Modulation: Codable, Equatable {
    public var aftertouch: ModulationTarget
    public var modwheel: ModulationTarget
    public var pitchbend: ModulationTarget
    public var velocity: ModulationTarget

    public init(aftertouch: ModulationTarget, modwheel: ModulationTarget, pitchbend: ModulationTarget, velocity: ModulationTarget) {
        self.aftertouch = aftertouch
        self.modwheel = modwheel
        self.pitchbend = pitchbend
        self.velocity = velocity
    }
}

public struct Engine: Codable, Equatable {
    public var bendrange: Int
    public var highpass: Int
    public var modulation: Modulation
    public var params: [Int]
    public var playmode: String
    public var portamentoAmount: Int
    public var portamentoType: Int
    public var transpose: Int
    public var tuningRoot: Int
    public var tuningScale: Int
    public var velocitySensitivity: Int
    public var volume: Int
    public var width: Int

    enum CodingKeys: String, CodingKey {
        case bendrange, highpass, modulation, params, playmode
        case portamentoAmount = "portamento.amount"
        case portamentoType = "portamento.type"
        case transpose
        case tuningRoot = "tuning.root"
        case tuningScale = "tuning.scale"
        case velocitySensitivity = "velocity.sensitivity"
        case volume, width
    }

    public init(bendrange: Int, highpass: Int, modulation: Modulation, params: [Int], playmode: String, portamentoAmount: Int, portamentoType: Int, transpose: Int, tuningRoot: Int, tuningScale: Int, velocitySensitivity: Int, volume: Int, width: Int) {
        self.bendrange = bendrange
        self.highpass = highpass
        self.modulation = modulation
        self.params = params
        self.playmode = playmode
        self.portamentoAmount = portamentoAmount
        self.portamentoType = portamentoType
        self.transpose = transpose
        self.tuningRoot = tuningRoot
        self.tuningScale = tuningScale
        self.velocitySensitivity = velocitySensitivity
        self.volume = volume
        self.width = width
    }
}

public struct ADSR: Codable, Equatable {
    public var attack: Int
    public var decay: Int
    public var release: Int
    public var sustain: Int

    public init(attack: Int, decay: Int, release: Int, sustain: Int) {
        self.attack = attack
        self.decay = decay
        self.release = release
        self.sustain = sustain
    }
}

public struct Envelope: Codable, Equatable {
    public var amp: ADSR
    public var filter: ADSR

    public init(amp: ADSR, filter: ADSR) {
        self.amp = amp
        self.filter = filter
    }
}

/// Shared shape for both the `fx` and `lfo` blocks: an active flag, eight
/// params, and a type name.
public struct EffectBlock: Codable, Equatable {
    public var active: Bool
    public var params: [Int]
    public var type: String

    public init(active: Bool, params: [Int], type: String) {
        self.active = active
        self.params = params
        self.type = type
    }
}
