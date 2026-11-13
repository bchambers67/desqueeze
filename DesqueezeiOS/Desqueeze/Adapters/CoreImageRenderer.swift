import CoreImage
import CoreImage.CIFilterBuiltins
import DesqueezeCore
import UIKit

/// Core Image, fitted to the session's `FrameRenderer` seam.
///
/// Core Image has a filter made for this job. `CILanczosScaleTransform` takes a
/// `scale` and an `aspectRatio`, where aspect ratio is a further horizontal
/// multiplier applied after the uniform scale. Holding `scale` at 1 and passing
/// the squeeze factor as `aspectRatio` widens the frame, leaves its height
/// alone, and reconstructs with Lanczos.
///
/// An actor so that decode and render stay off the main thread and never
/// overlap; the session awaits frames that are already rasterised.
actor CoreImageRenderer: FrameRenderer {

    /// A rasterised frame. `CGImage` is immutable, so handing it across
    /// isolation is safe even though the type predates `Sendable`.
    struct Frame: @unchecked Sendable {
        let image: CGImage
    }

    enum Failure: LocalizedError {
        case undecodable, renderFailed

        var errorDescription: String? {
            switch self {
            case .undecodable:  "That file could not be read as an image."
            case .renderFailed: "The image could not be rendered."
            }
        }
    }

    /// One shared context: building a `CIContext` per render is expensive and
    /// throws away Core Image's cache of compiled kernels.
    private let context = CIContext(options: [
        // Linear wide-gamut working space, so resampling does not clip
        // saturated colour on a P3 display.
        .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) as Any,
    ])
    private let outputSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()

    private func image(from source: Data) throws -> CIImage {
        guard let image = CIImage(data: source, options: [.applyOrientationProperty: true]) else {
            throw Failure.undecodable
        }
        return image
    }

    private func widened(_ image: CIImage, by squeeze: Squeeze) -> CIImage {
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = 1
        filter.aspectRatio = Float(squeeze.factor)
        return filter.outputImage ?? image
    }

    // MARK: - FrameRenderer

    func size(of source: Data) async throws -> PixelSize {
        let extent = try image(from: source).extent
        return PixelSize(width: Int(extent.width.rounded()), height: Int(extent.height.rounded()))
    }

    func preview(of source: Data, squeeze: Squeeze, longestEdge: Int) async throws -> Frame {
        var output = widened(try image(from: source), by: squeeze)
        let longest = max(output.extent.width, output.extent.height)
        if longest > CGFloat(longestEdge) {
            let ratio = CGFloat(longestEdge) / longest
            output = output.transformed(by: CGAffineTransform(scaleX: ratio, y: ratio))
        }
        guard let cg = context.createCGImage(output, from: output.extent, format: .RGBA8, colorSpace: outputSpace) else {
            throw Failure.renderFailed
        }
        return Frame(image: cg)
    }

    func export(_ source: Data, squeeze: Squeeze) async throws -> Data {
        let output = widened(try image(from: source), by: squeeze)
        let quality = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        guard let jpeg = context.jpegRepresentation(of: output, colorSpace: outputSpace, options: [quality: 0.92]) else {
            throw Failure.renderFailed
        }
        return jpeg
    }
}
