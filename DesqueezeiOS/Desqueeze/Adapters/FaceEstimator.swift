import CoreGraphics
import DesqueezeCore
import Foundation
import ImageIO
import Vision

/// Suggests a squeeze factor from the shape of the faces in a photo.
///
/// Faces in ordinary photographs have a fairly stable width-to-height ratio.
/// Shot through anamorphic glass and shown uncorrected, they come out narrow by
/// exactly the squeeze factor, so dividing the usual ratio by the measured one
/// recovers it. The same method as the macOS app, on the same constants.
enum FaceEstimator {

    /// Typical W:H of a Vision face box on an unsqueezed photo.
    private static let referenceAspect = 0.75
    /// Outside this, a reading is more likely a bad detection than real glass.
    private static let plausible = 1.10...2.30

    /// A suggested factor, or `nil` when the photo gives no usable reading.
    static func suggestion(for source: Data) async -> Double? {
        await Task.detached(priority: .utility) { measure(source) }.value
    }

    private static func measure(_ source: Data) -> Double? {
        guard let imageSource = CGImageSourceCreateWithData(source as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double,
              width > 0, height > 0
        else { return nil }

        let request = VNDetectFaceRectanglesRequest()
        // Vision is handed the file, so it applies the stored orientation
        // itself; the pixel sizes above are pre-rotation, and the box is
        // normalised, so swap them when the image is stored on its side.
        let orientation = (properties[kCGImagePropertyOrientation] as? UInt32).flatMap(CGImagePropertyOrientation.init) ?? .up
        let sideways = [.left, .right, .leftMirrored, .rightMirrored].contains(orientation)
        let (w, h) = sideways ? (height, width) : (width, height)

        let handler = VNImageRequestHandler(data: source, orientation: orientation, options: [:])
        guard (try? handler.perform([request])) != nil,
              let faces = request.results, !faces.isEmpty
        else { return nil }

        let readings = faces.compactMap { face -> Double? in
            let faceWidth = face.boundingBox.width * w
            let faceHeight = face.boundingBox.height * h
            guard faceWidth > 0, faceHeight > 0 else { return nil }
            let factor = referenceAspect / (faceWidth / faceHeight)
            return plausible.contains(factor) ? factor : nil
        }.sorted()

        // The median, so one odd face in a group does not decide it.
        return readings.isEmpty ? nil : readings[readings.count / 2]
    }
}

extension SqueezePreset {
    /// The preset a measured factor most likely is, or `nil` when it is not
    /// close to any and should be offered as a custom value instead.
    static func nearest(to factor: Double, within tolerance: Double = 0.08) -> SqueezePreset? {
        selectable
            .compactMap { preset in preset.factor.map { (preset, abs($0 - factor)) } }
            .min { $0.1 < $1.1 }
            .flatMap { $0.1 <= tolerance ? $0.0 : nil }
    }
}
