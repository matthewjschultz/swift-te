import Foundation
import TECore

public enum SpliceMode {
    case evenSlices(count: Int)
    case silence(thresholdDB: Float, minSilenceSeconds: Float)
    case onsets(sensitivity: Float)
}

public struct SpliceRange: Equatable {
    public let start: Int
    public let end: Int
}

public enum DrumSplicer {

    public static func splice(_ samples: [Float], sampleRate: Int, mode: SpliceMode) -> [SpliceRange] {
        switch mode {
        case .evenSlices(let count):
            return evenSlices(samples.count, count: count)
        case .silence(let thresholdDB, let minSilenceSeconds):
            return silenceSplit(samples, sampleRate: sampleRate, thresholdDB: thresholdDB, minSilenceSeconds: minSilenceSeconds)
        case .onsets(let sensitivity):
            return onsetSplit(samples, sampleRate: sampleRate, sensitivity: sensitivity)
        }
    }

    private static func evenSlices(_ totalFrames: Int, count: Int) -> [SpliceRange] {
        guard count > 0 else { return [] }
        var ranges: [SpliceRange] = []
        for i in 0..<count {
            let start = totalFrames * i / count
            let end = totalFrames * (i + 1) / count
            ranges.append(SpliceRange(start: start, end: end))
        }
        return ranges
    }

    /// Splits on runs of low-RMS windows lasting at least `minSilenceSeconds`.
    private static func silenceSplit(_ samples: [Float], sampleRate: Int, thresholdDB: Float, minSilenceSeconds: Float) -> [SpliceRange] {
        let windowSize = max(1, sampleRate / 100) // 10ms windows
        let threshold = pow(10, thresholdDB / 20)
        let minSilenceWindows = max(1, Int((minSilenceSeconds * Float(sampleRate) / Float(windowSize)).rounded()))

        var windowIsSilent: [Bool] = []
        var i = 0
        while i < samples.count {
            let end = min(i + windowSize, samples.count)
            let window = Array(samples[i..<end])
            windowIsSilent.append(PCM.rms(window) < threshold)
            i += windowSize
        }

        var ranges: [SpliceRange] = []
        var segmentStartWindow = 0
        var silentRunLength = 0
        for (windowIndex, isSilent) in windowIsSilent.enumerated() {
            if isSilent {
                silentRunLength += 1
                if silentRunLength == minSilenceWindows {
                    let segmentEndWindow = windowIndex - minSilenceWindows + 1
                    if segmentEndWindow > segmentStartWindow {
                        ranges.append(SpliceRange(start: segmentStartWindow * windowSize, end: min(segmentEndWindow * windowSize, samples.count)))
                    }
                    segmentStartWindow = windowIndex + 1
                }
            } else {
                silentRunLength = 0
            }
        }
        if segmentStartWindow * windowSize < samples.count {
            ranges.append(SpliceRange(start: segmentStartWindow * windowSize, end: samples.count))
        }
        return ranges
    }

    /// An original, energy-derivative onset detector: NOT a port of
    /// teoperator's aubio-backed transient detection, which uses spectral
    /// flux. This finds local peaks in the frame-to-frame RMS increase,
    /// which approximates "where a new sound starts" without matching
    /// aubio's algorithm or its exact output.
    private static func onsetSplit(_ samples: [Float], sampleRate: Int, sensitivity: Float) -> [SpliceRange] {
        let hopSize = max(1, sampleRate / 100) // 10ms hops
        var rmsEnvelope: [Float] = []
        var i = 0
        while i < samples.count {
            let end = min(i + hopSize, samples.count)
            rmsEnvelope.append(PCM.rms(Array(samples[i..<end])))
            i += hopSize
        }

        guard rmsEnvelope.count > 1 else {
            return [SpliceRange(start: 0, end: samples.count)]
        }

        var onsetStrength: [Float] = [0]
        for i in 1..<rmsEnvelope.count {
            onsetStrength.append(max(0, rmsEnvelope[i] - rmsEnvelope[i - 1]))
        }

        let peakValue = onsetStrength.max() ?? 0
        guard peakValue > 0 else {
            return [SpliceRange(start: 0, end: samples.count)]
        }
        let threshold = peakValue * (1 - sensitivity)
        let minSpacingWindows = max(1, Int(0.05 * Float(sampleRate) / Float(hopSize))) // 50ms minimum spacing

        var onsetWindows: [Int] = []
        var lastOnset = -minSpacingWindows
        for (windowIndex, strength) in onsetStrength.enumerated() {
            if strength >= threshold && windowIndex - lastOnset >= minSpacingWindows {
                onsetWindows.append(windowIndex)
                lastOnset = windowIndex
            }
        }

        var boundaries = [0] + onsetWindows.map { $0 * hopSize } + [samples.count]
        boundaries = Array(Set(boundaries)).sorted()

        var ranges: [SpliceRange] = []
        for i in 0..<(boundaries.count - 1) {
            ranges.append(SpliceRange(start: boundaries[i], end: boundaries[i + 1]))
        }
        return ranges
    }
}
