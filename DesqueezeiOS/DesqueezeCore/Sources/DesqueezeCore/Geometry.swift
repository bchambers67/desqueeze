import Foundation

/// A size in image pixels. Integer on purpose: these are counts, not lengths.
public struct PixelSize: Equatable, Sendable {
    public var width: Int
    public var height: Int
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// An anamorphic correction: widen by `factor`, leave the height alone.
public struct Squeeze: Equatable, Sendable {
    public let factor: Double
    public init(factor: Double) { self.factor = factor }

    public func outputSize(for source: PixelSize) -> PixelSize {
        PixelSize(width: Int((Double(source.width) * factor).rounded()), height: source.height)
    }

    /// Width over height of the corrected frame.
    public func aspectRatio(for source: PixelSize) -> Double {
        let out = outputSize(for: source)
        return Double(out.width) / Double(out.height)
    }

    /// The span a hand-entered factor is held to. Below 1 is not a de-squeeze;
    /// nothing made squeezes past 2, and 3 leaves room for the unusual.
    public static let typedRange: ClosedRange<Double> = 1.0...3.0

    /// A factor as someone typed it. `nil` when the text is not a number;
    /// clamped to `typedRange` when it is.
    public init?(typed text: String) {
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite else { return nil }
        self.factor = min(max(value, Self.typedRange.lowerBound), Self.typedRange.upperBound)
    }
}
