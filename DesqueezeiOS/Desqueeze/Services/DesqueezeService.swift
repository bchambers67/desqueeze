import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// The de-squeeze itself.
///
/// Core Image has a filter made for exactly this: `CILanczosScaleTransform`
/// takes a `scale` and an `aspectRatio`, where aspect ratio is an additional
/// horizontal multiplier applied after the uniform scale. Holding `scale` at 1
/// and passing the squeeze factor as `aspectRatio` widens the frame and leaves
/// its height untouched, with Lanczos resampling — which is the correct
/// reconstruction for this kind of single-axis upscale.
///
/// The type is an actor so that decode and render stay off the main thread and
/// cannot overlap; the UI awaits a `UIImage` that is already fully rendered.
actor DesqueezeService {

    /// One shared context. Creating a `CIContext` per render is expensive and
    /// defeats Core Image's internal caching of the compiled kernel.
    private let context: CIContext = {
        // Working in a linear, wide-gamut space keeps the resample from
        // clipping saturated colour on P3 displays such as the Duo's.
        CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
                ?? CGColorSpaceCreateDeviceRGB(),
            .outputColorSpace: CGColorSpace(name: CGColorSpace.displayP3)
                ?? CGColorSpaceCreateDeviceRGB(),
        ])
    }()

    enum Failure: LocalizedError {
        case undecodable
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .undecodable:  "That file could not be read as an image."
            case .renderFailed: "The image could not be rendered."
            }
        }
    }

    /// Loads image data without decoding the full bitmap up front.
    func makeImage(from data: Data) throws -> CIImage {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw Failure.undecodable
        }
        return image
    }

    /// Widens `image` by `factor`, leaving its height unchanged.
    func desqueeze(_ image: CIImage, factor: Double) -> CIImage {
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = 1
        filter.aspectRatio = Float(factor)
        // The filter is total over its domain; the fallback keeps the signature
        // non-optional rather than forcing callers to handle an impossible nil.
        return filter.outputImage ?? image
    }

    /// Renders to a `UIImage` suitable for display.
    ///
    /// `maxDimension` caps the rasterised size: a 48MP frame widened 2× is far
    /// larger than any Duo surface can show, and rendering it in full would cost
    /// memory for pixels that are immediately downsampled for the screen.
    func render(_ image: CIImage, maxDimension: CGFloat? = nil) throws -> UIImage {
        var output = image
        if let maxDimension {
            let longest = max(output.extent.width, output.extent.height)
            if longest > maxDimension {
                let ratio = maxDimension / longest
                output = output.transformed(by: .init(scaleX: ratio, y: ratio))
            }
        }

        guard let cg = context.createCGImage(output, from: output.extent) else {
            throw Failure.renderFailed
        }
        return UIImage(cgImage: cg)
    }

    /// Convenience: decode, widen, and rasterise in one hop off the main actor.
    func process(data: Data, factor: Double, maxDimension: CGFloat?) throws -> UIImage {
        let source = try makeImage(from: data)
        return try render(desqueeze(source, factor: factor), maxDimension: maxDimension)
    }

    /// Full-resolution JPEG for export, at the image's native widened size.
    func encodeJPEG(data: Data, factor: Double, quality: Double = 0.92) throws -> Data {
        let source = try makeImage(from: data)
        let widened = desqueeze(source, factor: factor)

        guard let out = context.jpegRepresentation(
            of: widened,
            colorSpace: CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB(),
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
        ) else {
            throw Failure.renderFailed
        }
        return out
    }
}
