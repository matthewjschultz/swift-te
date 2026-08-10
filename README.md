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
.package(url: "https://github.com/mjschultz/swift-te", from: "0.1.0")
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

```swift
import TEOPXY

let slots = [DrumSlot(samples: kick, sourceSampleRate: 44100, fileName: "kick.wav"), ...]
let preset = DrumPresetBuilder.build(name: "kit", slots: slots)
let zip = try OPXYPackage.write(preset: preset, samples: [kick, ...], names: ["kick.wav", ...])
try zip.write(to: URL(fileURLWithPath: "kit.preset.zip"))
```

## License

MIT. See LICENSE and NOTICE.md.
