import Foundation

/// Percent-facing UI values map to 0-32767 internal units on the device.
/// Matches op-patchstudio's percentToInternal/internalToPercent exactly —
/// get this wrong and a preset's engine parameters silently mean something
/// different on the OP-XY than the percentage implies.
public enum ValueConversions {
    public static func percentToInternal(_ percent: Double) -> Int {
        Int((percent / 100 * 32767).rounded())
    }

    public static func internalToPercent(_ internalValue: Int) -> Int {
        Int((Double(internalValue) / 32767 * 100).rounded())
    }
}
