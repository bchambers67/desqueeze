import Foundation

/// Ways of reading a squeeze factor from the picture itself.
///
/// Each takes plain measurements and returns the factor they imply, or `nil`
/// when they say nothing. None is trusted alone: `SqueezeDetector` flags a
/// photo only when readings agree. The reference proportions here are
/// estimates and are the first things to tune against real photographs. They
/// are also the features a trained model would start from.
public enum PictureSignals {

    // MARK: - Direction of fine detail

    /// The squeeze implied by how much denser fine detail is across the frame
    /// than down it.
    ///
    /// Texture in an ordinary photograph changes about as fast in one
    /// direction as another. Squeezing the frame sideways makes it change
    /// faster across than down, by the squeeze factor. The frame is measured
    /// patch by patch and the middle patch's answer is kept, so one strong
    /// line, a horizon or a wall edge, cannot decide it.
    ///
    /// - Parameter pixels: grey levels, one byte each, row by row.
    public static func detailFactor(pixels: [UInt8], width: Int, height: Int, grid: Int = 6) -> Double? {
        guard width >= grid * 8, height >= grid * 8, pixels.count >= width * height else { return nil }
        let patchWidth = width / grid, patchHeight = height / grid
        var ratios: [Double] = []

        for row in 0..<grid {
            for column in 0..<grid {
                var across = 0.0, down = 0.0
                let x0 = max(column * patchWidth, 1), x1 = min((column + 1) * patchWidth, width - 1)
                let y0 = max(row * patchHeight, 1), y1 = min((row + 1) * patchHeight, height - 1)
                for y in y0..<y1 {
                    let line = y * width
                    for x in x0..<x1 {
                        let dx = Double(pixels[line + x + 1]) - Double(pixels[line + x - 1])
                        let dy = Double(pixels[line + width + x]) - Double(pixels[line - width + x])
                        across += dx * dx
                        down += dy * dy
                    }
                }
                let count = Double((x1 - x0) * (y1 - y0))
                // Flat patches, sky or a plain wall, have nothing to measure.
                guard count > 0, (across + down) / count > minimumDetail, down > 0 else { continue }
                ratios.append((across / down).squareRoot())
            }
        }
        // Too few textured patches to speak for the frame.
        guard ratios.count >= grid * grid / 4 else { return nil }
        ratios.sort()
        return ratios[ratios.count / 2]
    }

    /// Mean squared grey-level change below which a patch counts as flat.
    static let minimumDetail = 6.0

    // MARK: - Shape of text

    /// One recognised line of text, in pixels.
    public struct TextLine: Sendable {
        public var characters: Int
        public var width: Double
        public var height: Double
        public init(characters: Int, width: Double, height: Double) {
            self.characters = characters
            self.width = width
            self.height = height
        }
    }

    /// Width of a character over the height of its line, for ordinary type.
    public static let typicalCharacterAspect = 0.55

    /// The squeeze implied by how narrow the letters are.
    public static func textFactor(lines: [TextLine]) -> Double? {
        let aspects = lines.compactMap { line -> Double? in
            // Short strings are dominated by which letters they happen to be,
            // and a box taller than it is wide is text set on its side.
            guard line.characters >= 4, line.height > 0, line.width > line.height else { return nil }
            return (line.width / Double(line.characters)) / line.height
        }.sorted()
        guard aspects.count >= 2 else { return nil }
        return typicalCharacterAspect / aspects[aspects.count / 2]
    }

    // MARK: - Body proportions

    /// One person, in pixels: shoulder to shoulder, and neck to hips.
    public struct Body: Sendable {
        public var shoulderWidth: Double
        public var torsoLength: Double
        public init(shoulderWidth: Double, torsoLength: Double) {
            self.shoulderWidth = shoulderWidth
            self.torsoLength = torsoLength
        }
    }

    /// Shoulder width over torso length for someone facing the camera.
    public static let typicalShoulderToTorso = 0.72

    /// The squeeze implied by how narrow people's shoulders are.
    ///
    /// Someone turned away from the camera also has narrow shoulders, so the
    /// widest person is the one measured: in a group, somebody is facing
    /// forward. With one person the reading can be a turned body, which is
    /// why it is never trusted alone.
    public static func bodyFactor(people: [Body]) -> Double? {
        let widest = people
            .filter { $0.torsoLength > 0 && $0.shoulderWidth > 0 }
            .map { $0.shoulderWidth / $0.torsoLength }
            .max()
        return widest.map { typicalShoulderToTorso / $0 }
    }

    // MARK: - The same session as a corrected photo

    /// A photo the owner has corrected: when it was taken, its size, and the
    /// factor they used.
    public struct Correction: Codable, Sendable, Equatable {
        public var taken: Date
        public var size: PixelSize
        public var factor: Double
        public init(taken: Date, size: PixelSize, factor: Double) {
            self.taken = taken
            self.size = size
            self.factor = factor
        }
    }

    /// The factor of a corrected photo taken within `window` seconds of this
    /// one, at the same pixel size: the same lens was almost certainly on
    /// the camera. The nearest in time wins.
    public static func sessionFactor(taken: Date, size: PixelSize, corrections: [Correction],
                                     window: TimeInterval = 600) -> Double? {
        corrections
            .filter { $0.size == size && abs($0.taken.timeIntervalSince(taken)) <= window }
            .min { abs($0.taken.timeIntervalSince(taken)) < abs($1.taken.timeIntervalSince(taken)) }?
            .factor
    }
}
