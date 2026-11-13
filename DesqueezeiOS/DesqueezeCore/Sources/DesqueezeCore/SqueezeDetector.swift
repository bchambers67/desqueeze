import Foundation

/// What can be read about a photo without looking at its pixels, plus one
/// thing that can: how narrow its faces are.
public struct PhotoFacts: Sendable {
    public var name: String?
    public var size: PixelSize
    /// The lens as the camera recorded it, when it recorded one.
    public var lensModel: String?
    /// A squeeze factor measured from faces, when there are any.
    public var faceFactor: Double?
    public var isScreenshot: Bool
    /// Edited in the photo library since it was taken.
    public var isEdited: Bool

    public init(name: String?, size: PixelSize, lensModel: String?, faceFactor: Double?,
                isScreenshot: Bool, isEdited: Bool) {
        self.name = name
        self.size = size
        self.lensModel = lensModel
        self.faceFactor = faceFactor
        self.isScreenshot = isScreenshot
        self.isEdited = isEdited
    }
}

/// Decides whether a photo was shot through anamorphic glass and still needs
/// correcting.
///
/// Two signs count. A lens that names itself anamorphic is the surer one, and
/// often states its factor. Faces that are clearly too narrow are the other.
/// A photo with neither is left alone: a wrong guess here would queue someone's
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

    public enum Reason: Equatable, Sendable { case lens, faces }

    /// Faces narrower than this are taken as squeezed. Below it, the reading
    /// is within what ordinary faces and loose detections produce.
    public static let faceThreshold = 1.25

    /// A frame this wide is a corrected one, or a panorama.
    public static let alreadyWide = 2.2

    public static func verdict(for facts: PhotoFacts) -> Verdict? {
        guard !facts.isScreenshot, !facts.isEdited else { return nil }
        if let name = facts.name?.lowercased(), name.contains("desqueeze") { return nil }
        guard facts.size.height > 0,
              Double(facts.size.width) / Double(facts.size.height) < alreadyWide else { return nil }

        let faces = facts.faceFactor.flatMap { $0 >= faceThreshold ? snapped($0) : nil }

        if let lens = facts.lensModel?.lowercased(), lens.contains("anamorph") || lens.contains("nanomorph") {
            return Verdict(factor: statedFactor(in: lens) ?? faces, reason: .lens)
        }
        if let faces {
            return Verdict(factor: faces, reason: .faces)
        }
        return nil
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
