import Foundation
import TECore

public enum OPXYPackageError: Error, Equatable {
    case sampleNameCountMismatch
    case encodingFailed
}

/// Packages a preset and its samples into the zip op-patchstudio produces:
/// `patch.json` and each sample file at the archive root, with no wrapping
/// subfolder. The caller names the zip itself (conventionally
/// `<presetName>.preset.zip`) — that's a filesystem concern, not part of
/// the archive's internal layout.
public enum OPXYPackage {

    public static func write(preset: DrumPreset, samples: [Data], names: [String]) throws -> Data {
        guard samples.count == names.count else { throw OPXYPackageError.sampleNameCountMismatch }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(preset) else { throw OPXYPackageError.encodingFailed }
        return package(json: json, samples: samples, names: names)
    }

    public static func write(preset: MultisamplePreset, samples: [Data], names: [String]) throws -> Data {
        guard samples.count == names.count else { throw OPXYPackageError.sampleNameCountMismatch }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(preset) else { throw OPXYPackageError.encodingFailed }
        return package(json: json, samples: samples, names: names)
    }

    private static func package(json: Data, samples: [Data], names: [String]) -> Data {
        var writer = ZipWriter()
        writer.addEntry(name: "patch.json", data: json)
        for (sampleData, name) in zip(samples, names) {
            writer.addEntry(name: name, data: sampleData)
        }
        return writer.finalize()
    }
}
