import AppKit
import Vision
import CoreGraphics

/// Estimates an anamorphic squeeze factor from an image by measuring the
/// aspect ratio of faces detected via Vision's on-device neural face detector.
///
/// Faces in unsqueezed photographs have a fairly stable bounding-box width-to-height
/// ratio. When an image is captured with an anamorphic lens and shown un-desqueezed,
/// faces appear vertically elongated by the squeeze factor. Dividing the reference
/// aspect by the observed aspect therefore recovers the factor.
enum SqueezeEstimator {

    /// Average W:H of a Vision face bounding box on un-squeezed photos.
    /// Calibrated empirically — Vision boxes are roughly from chin to brow.
    private static let referenceFaceAspect: CGFloat = 0.75

    /// Plausible bounds for an anamorphic squeeze. Outside this range we treat
    /// the detection as unreliable rather than a real anamorphic capture.
    private static let validRange: ClosedRange<CGFloat> = 1.10...2.30

    /// Returns a suggested squeeze factor, or `nil` if no usable signal was found.
    static func estimateFactor(for image: NSImage) async -> CGFloat? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return await Task.detached(priority: .userInitiated) {
            detect(cgImage: cgImage)
        }.value
    }

    /// Snaps a measured factor to the closest preset within a small tolerance,
    /// returning `.custom` if the factor is far from every preset.
    static func suggestedPreset(for factor: CGFloat) -> SqueezePreset {
        let tolerance: CGFloat = 0.08
        let presets: [(SqueezePreset, CGFloat)] = [
            (.x133, 1.33), (.x150, 1.50), (.x200, 2.00),
        ]
        let nearest = presets.min { abs($0.1 - factor) < abs($1.1 - factor) }
        if let nearest, abs(nearest.1 - factor) <= tolerance {
            return nearest.0
        }
        return .custom
    }

    private static func detect(cgImage: CGImage) -> CGFloat? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observations = request.results, !observations.isEmpty else { return nil }

        let imageW = CGFloat(cgImage.width)
        let imageH = CGFloat(cgImage.height)

        let factors: [CGFloat] = observations.compactMap { obs in
            let pxW = obs.boundingBox.width * imageW
            let pxH = obs.boundingBox.height * imageH
            guard pxW > 0, pxH > 0 else { return nil }
            let aspect = pxW / pxH
            let factor = referenceFaceAspect / aspect
            return validRange.contains(factor) ? factor : nil
        }

        guard !factors.isEmpty else { return nil }
        let sorted = factors.sorted()
        return sorted[sorted.count / 2]
    }
}
