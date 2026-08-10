# Swift-TE

Reads and writes the patch formats used by Teenage Engineering's OP-1,
OP-Z, and OP-XY. Pure Swift, no external dependencies, no shelling out to
ffmpeg or any other tool.

Neither format is publicly documented by Teenage Engineering. The format
knowledge here comes from two open source projects that reverse-engineered
it: [teoperator](https://github.com/schollz/teoperator) (OP-1/OP-Z, Go) and
[op-patchstudio](https://github.com/joseph-holland/op-patchstudio) (OP-XY,
TypeScript). Swift-TE is an independent Swift implementation built from
that same format knowledge, not a translation of either codebase. See
NOTICE.md for full credit.

## Install

Add it as a package dependency:

```swift
.package(url: "https://github.com/matthewjschultz/swift-te", from: "0.1.0")
```

Or, while it's local-only, as a path dependency pointing at a checkout.

## Usage

### OP-1 / OP-Z synth patch

```swift
import TEOP1

let patch = SynthPatch.synthSample(baseFrequency: 220.0)
let aiff = try SynthPatchCodec.encode(patch, samples: pcmSamples, sampleRate: 44100)
try aiff.write(to: URL(fileURLWithPath: "piano.aif"))
```

### OP-1 / OP-Z drum kit

```swift
import TEOP1

let result = DrumKit.build(from: oneShotClips, sampleRate: 44100)
let aiff = try DrumPatchCodec.encode(result.patch, samples: result.samples, sampleRate: result.sampleRate)
try aiff.write(to: URL(fileURLWithPath: "kit.aif"))
```

### OP-XY drum preset

`kick` and `snare` here are `[Float]` buffers of mono PCM. The preset
builder takes those raw buffers, but the package writer takes encoded
sample files, so each buffer is written out as a WAV first.

```swift
import TECore
import TEOPXY

let slots = [
    DrumSlot(samples: kick, sourceSampleRate: 44100, fileName: "kick.wav"),
    DrumSlot(samples: snare, sourceSampleRate: 44100, fileName: "snare.wav"),
]
let preset = DrumPresetBuilder.build(name: "kit", slots: slots)

let sampleFiles = try slots.map { slot in
    try WAVFile(sampleRate: slot.sourceSampleRate, bitDepth: 16, channelCount: 1, samples: slot.samples).encoded()
}
let zip = try OPXYPackage.write(preset: preset, samples: sampleFiles, names: slots.map(\.fileName))
try zip.write(to: URL(fileURLWithPath: "kit.preset.zip"))
```

### OP-XY multisample preset

`c3` and `c4` here are `[Float]` buffers of mono PCM, one per sampled note.
Zones must be passed in ascending `rootNote` order — the builder splits the
keyboard between them from that order, not from any key field.

```swift
import TECore
import TEOPXY

let zones = [
    MultisampleZone(samples: c3, sourceSampleRate: 44100, fileName: "c3.wav", rootNote: 60),
    MultisampleZone(samples: c4, sourceSampleRate: 44100, fileName: "c4.wav", rootNote: 72),
]
let preset = MultisamplePresetBuilder.build(name: "keys", zones: zones)

let sampleFiles = try zones.map { zone in
    try WAVFile(sampleRate: zone.sourceSampleRate, bitDepth: 16, channelCount: 1, samples: zone.samples).encoded()
}
let zip = try OPXYPackage.write(preset: preset, samples: sampleFiles, names: zones.map(\.fileName))
try zip.write(to: URL(fileURLWithPath: "keys.preset.zip"))
```

## License

MIT. See LICENSE and NOTICE.md.
