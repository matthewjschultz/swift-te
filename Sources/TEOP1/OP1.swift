import Foundation

public enum OP1 {
    public static let sampleRate = 44100
    /// Largest value ever observed in a sample end point.
    public static let maxEndPoint: Int64 = 2_147_483_646
    /// Fixed-point scale between seconds-at-44.1kHz and the on-device
    /// sample offset representation: 2147483646 / (44100 * 12) ≈ 4058.
    public static let sampleConversion: Int64 = 4058

    public static func frameOffset(seconds: Double) -> Int64 {
        let frames = (seconds * Double(sampleRate)).rounded(.down)
        return Int64(frames) * sampleConversion
    }
}
