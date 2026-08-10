import Foundation

public enum PCM {

    /// Averages an arbitrary number of channels down to one.
    public static func downmix(_ channels: [[Float]]) -> [Float] {
        guard let first = channels.first else { return [] }
        guard channels.count > 1 else { return first }
        var out = [Float](repeating: 0, count: first.count)
        for channel in channels {
            for i in 0..<min(channel.count, out.count) {
                out[i] += channel[i]
            }
        }
        let count = Float(channels.count)
        return out.map { $0 / count }
    }

    /// Linear-interpolation resample. Identity when rates match.
    public static func resample(_ input: [Float], from sourceRate: Int, to targetRate: Int) -> [Float] {
        guard sourceRate != targetRate else { return input }
        guard !input.isEmpty, sourceRate > 0, targetRate > 0 else { return [] }
        let outCount = Int((Double(input.count) * Double(targetRate) / Double(sourceRate)).rounded())
        guard outCount > 0 else { return [] }
        let lastIndex = input.count - 1
        var out = [Float](repeating: 0, count: outCount)
        for i in 0..<outCount {
            let sourcePosition = Double(i) * Double(sourceRate) / Double(targetRate)
            let baseIndex = Int(sourcePosition)
            let fraction = Float(sourcePosition - Double(baseIndex))
            let a = input[min(baseIndex, lastIndex)]
            let b = input[min(baseIndex + 1, lastIndex)]
            out[i] = a + (b - a) * fraction
        }
        return out
    }

    public static func peak(_ samples: [Float]) -> Float {
        samples.reduce(0) { max($0, abs($1)) }
    }

    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sumOfSquares / Float(samples.count)).squareRoot()
    }

    /// Scales `samples` so its peak lands at `targetPeakDB` (0 dB = full scale).
    public static func normalized(_ samples: [Float], targetPeakDB: Float) -> [Float] {
        let currentPeak = peak(samples)
        guard currentPeak > 0 else { return samples }
        let targetPeak = pow(10, targetPeakDB / 20)
        let gain = targetPeak / currentPeak
        return samples.map { $0 * gain }
    }

    /// Searches outward from `index` for the nearest sample where the
    /// signal crosses zero, within `searchRadius` samples either direction.
    /// Returns `index` unchanged if no crossing is found in range.
    public static func nearestZeroCrossing(_ samples: [Float], around index: Int, searchRadius: Int) -> Int {
        guard !samples.isEmpty else { return index }
        let clampedIndex = max(0, min(index, samples.count - 1))
        for offset in 0...searchRadius {
            let forward = clampedIndex + offset
            if forward > 0 && forward < samples.count {
                if (samples[forward - 1] < 0) != (samples[forward] < 0) {
                    return forward
                }
            }
            let backward = clampedIndex - offset
            if backward > 0 && backward < samples.count {
                if (samples[backward - 1] < 0) != (samples[backward] < 0) {
                    return backward
                }
            }
        }
        return clampedIndex
    }
}
