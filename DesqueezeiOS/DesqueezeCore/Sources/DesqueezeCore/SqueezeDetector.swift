import Foundation

/// Everything known about a photo that bears on whether it is squeezed.
public struct PhotoFacts: Sendable {
    public var name: String?
    public var size: PixelSize
    /// The lens as the camera recorded it, when it recorded one.
    public var lensModel: String?
    /// A squeeze factor measured from faces, when there are any.
    public var faceFactor: Double?
    /// The same, from the shape of text in the frame.
    public var textFactor: Double?
    /// The same, from the proportions of people's bodies.
    public var bodyFactor: Double?
    /// The same, from the direction of fine detail.
    public var detailFactor: Double?
    /// The factor of a corrected photo from the same session.
    public var sessionFactor: Double?
    public var isScreenshot: Bool
    /// Edited in the photo library since it was taken.
    public var isEdited: Bool

    public init(name: String?, size: PixelSize, lensModel: String?, faceFactor: Double?,
                textFactor: Double? = nil, bodyFactor: Double? = nil, detailFactor: Double? = nil,
                sessionFactor: Double? = nil, isScreenshot: Bool, isEdited: Bool) {
        self.name = name
        self.size = size
        self.lensModel = lensModel
        self.faceFactor = faceFactor
        self.textFactor = textFactor
        self.bodyFactor = bodyFactor
        self.detailFactor = detailFactor
        self.sessionFactor = sessionFactor
        self.isScreenshot = isScreenshot
        self.isEdited = isEdited
    }
}

/// Decides whether a photo was shot through anamorphic glass and still needs
/// correcting.
///
/// The sure signs are a lens that names itself anamorphic, and a photo the
/// owner corrected from the same few minutes. After those come readings taken
/// from the picture: faces, text, bodies and the direction of fine detail.
/// Faces are trusted alone. The others are looser, so they must agree with
/// one another, and a reading that says "ordinary" counts against. A photo
/// with no sign is left alone: a wrong guess here would queue someone's
/// ordinary photos for stretching.
public enum SqueezeDetector {

    public struct Verdict: Equatable, Sendable {
        /// `nil` when the photo is squeezed but nothing says by how much.
        public var factor: Double?
        public var reason: Reason
        public init(factor: Double?, reason: Reason) {
            self.factor = factor
            self.reason = reason
        }
    }

    public enum Reason: Equatable, Sendable {
        /// The camera recorded an anamorphic lens.
        case lens
        /// Taken alongside a photo the owner corrected.
        case session
        /// Faces alone.
        case faces
        /// Two or more readings from the picture, in agreement.
        case picture
    }

    /// Faces narrower than this are taken as squeezed. Below it, the reading
    /// is within what ordinary faces and loose detections produce.
    public static let faceThreshold = 1.25
    /// The same line for the looser readings.
    public static let pictureThreshold = 1.2
    /// A reading under this says the photo looks ordinary.
    public static let ordinaryBelow = 1.1
    /// How far apart readings may be and still count as agreeing.
    public static let agreement = 0.3

    /// A frame this wide is a corrected one, or a panorama.
    public static let alreadyWide = 2.2

    public static func verdict(for facts: PhotoFacts) -> Verdict? {
        guard !facts.isScreenshot, !facts.isEdited else { return nil }
        if let name = facts.name?.lowercased(), name.contains("desqueeze") { return nil }
        guard facts.size.height > 0,
              Double(facts.size.width) / Double(facts.size.height) < alreadyWide else { return nil }

        let faces = facts.faceFactor.flatMap { $0 >= faceThreshold ? $0 : nil }
        // Readings that can carry a verdict between them.
        let firm = [faces, squeezed(facts.textFactor), squeezed(facts.bodyFactor)].compactMap { $0 }
        // Detail is the loosest: it can back the others up, never lead, and
        // never count against.
        let all = firm + [squeezed(facts.detailFactor)].compactMap { $0 }
        let ordinary = [facts.faceFactor, facts.textFactor, facts.bodyFactor]
            .compactMap { $0 }.filter { $0 < ordinaryBelow }.count
        let consensus = all.isEmpty ? nil : snapped(median(all))

        if let lens = facts.lensModel?.lowercased(), lens.contains("anamorph") || lens.contains("nanomorph") {
            return Verdict(factor: statedFactor(in: lens) ?? consensus, reason: .lens)
        }
        if let session = facts.sessionFactor {
            return Verdict(factor: session, reason: .session)
        }

        // From here the picture is all there is to go on.
        guard !firm.isEmpty, all.count > ordinary, let consensus else { return nil }
        if all.count >= 2 {
            guard all.max()! - all.min()! <= agreement else { return nil }
            return Verdict(factor: consensus, reason: .picture)
        }
        // One reading: only faces are trusted alone.
        return faces.map { _ in Verdict(factor: consensus, reason: .faces) }
    }

    private static func squeezed(_ reading: Double?) -> Double? {
        reading.flatMap { $0 >= pictureThreshold ? $0 : nil }
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// A measured factor, moved onto a lens preset when it is close to one.
    private static func snapped(_ factor: Double) -> Double {
        let presets = SqueezePreset.selectable.compactMap(\.factor)
        if let nearest = presets.min(by: { abs($0 - factor) < abs($1 - factor) }), abs(nearest - factor) <= 0.08 {
            return nearest
        }
        return (factor * 100).rounded() / 100
    }

    /// The factor in a lens name, written as lens makers write it: "1.6x",
    /// "1.33X", "2x". A bare number is not enough, or "50mm" would count.
    private static func statedFactor(in lens: String) -> Double? {
        let pattern = #/(?:^|[^\d.])([12](?:\.\d{1,2})?)\s?x(?:$|[^a-z0-9])/#
        guard let match = lens.firstMatch(of: pattern), let value = Double(match.1),
              Squeeze.typedRange.contains(value), value > 1 else { return nil }
        return value
    }
}
