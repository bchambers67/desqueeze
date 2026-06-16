import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Writes desqueezed images to disk while preserving the source file's
/// metadata (capture date, camera make/model, lens, GPS, EXIF, etc.).
/// `NSBitmapImageRep` drops this metadata, so we round-trip through ImageIO
/// and copy the source's properties dictionary onto the output.
enum ImageWriter {
    /// Read the full metadata properties dictionary from a source file.
    static func readProperties(from url: URL) -> [CFString: Any]? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        else { return nil }
        return props
    }

    /// Read the full metadata properties dictionary from raw image data.
    static func readProperties(from data: Data) -> [CFString: Any]? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        else { return nil }
        return props
    }

    /// Map a file extension to the destination image type.
    static func fileType(forExtension ext: String) -> UTType {
        switch ext.lowercased() {
        case "png":          return .png
        case "tif", "tiff":  return .tiff
        default:             return .jpeg
        }
    }

    /// Encode `cgImage` to `url` as `utType`, merging in `sourceProperties` so
    /// capture date, camera, lens, and other metadata survive the export.
    /// Pixel-dimension tags are updated to match the desqueezed output so the
    /// stored metadata stays consistent with the wider image.
    static func write(
        _ cgImage: CGImage,
        to url: URL,
        utType: UTType,
        sourceProperties: [CFString: Any]?,
        jpegQuality: CGFloat?
    ) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, utType.identifier as CFString, 1, nil
        ) else { return false }

        var props = sourceProperties ?? [:]
        props[kCGImagePropertyPixelWidth] = cgImage.width
        props[kCGImagePropertyPixelHeight] = cgImage.height

        if var exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = cgImage.width
            exif[kCGImagePropertyExifPixelYDimension] = cgImage.height
            props[kCGImagePropertyExifDictionary] = exif
        }
        if let jpegQuality {
            props[kCGImageDestinationLossyCompressionQuality] = jpegQuality
        }

        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
        return CGImageDestinationFinalize(dest)
    }
}

enum SqueezePreset: String, CaseIterable, Identifiable {
    case x125  = "1.25×"
    case x133  = "1.33×"
    case x150  = "1.50×"
    case x155  = "1.55×"
    case x160  = "1.60×"
    case x165  = "1.65×"
    case x175  = "1.75×"
    case x180  = "1.80×"
    case x200  = "2.00×"
    case custom = "Custom"

    var id: String { rawValue }

    var factor: CGFloat? {
        switch self {
        case .x125:   return 1.25
        case .x133:   return 1.33
        case .x150:   return 1.50
        case .x155:   return 1.55
        case .x160:   return 1.60
        case .x165:   return 1.65
        case .x175:   return 1.75
        case .x180:   return 1.80
        case .x200:   return 2.00
        case .custom: return nil
        }
    }
}

@MainActor
class DesqueezeProcessor: ObservableObject {
    @Published var sourceImage: NSImage?
    @Published var processedImage: NSImage?
    @Published var selectedPreset: SqueezePreset = .x150
    @Published var customFactor: String = "1.33"
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var suggestedFactor: CGFloat?
    @Published var suggestedPreset: SqueezePreset?
    @Published var isEstimating: Bool = false

    /// Source URL when the image was opened by an external editor
    /// (Lightroom CC "Edit In…", Finder "Open With"). When set, the export
    /// flow writes the desqueezed result back to this same path so the host
    /// re-imports the change.
    @Published var roundTripURL: URL?
    @Published var savedToRoundTrip: Bool = false

    /// URL of the original file the current image was loaded from, if any.
    /// Used to suggest a default export filename. Nil when the image has no
    /// backing file (e.g. pasted or dropped as raw image data).
    @Published var sourceURL: URL?

    /// Metadata (EXIF/TIFF/GPS, capture date, camera, lens…) read from the
    /// source file so it can be re-applied to the exported image.
    private var sourceProperties: [CFString: Any]?

    var isRoundTrip: Bool { roundTripURL != nil }

    /// Default filename for the export save panel: the original filename with
    /// "_desqueezed" appended (extension dropped — the panel adds it based on
    /// the chosen content type). Falls back to "desqueezed" when there's no
    /// backing file.
    var suggestedExportName: String {
        guard let base = sourceURL?.deletingPathExtension().lastPathComponent,
              !base.isEmpty else {
            return "desqueezed"
        }
        return "\(base)_desqueezed"
    }

    var activeFactor: CGFloat {
        selectedPreset == .custom
            ? CGFloat(Double(customFactor) ?? 1.33)
            : (selectedPreset.factor ?? 1.50)
    }

    func loadImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            errorMessage = "Could not load image from that file."
            return
        }
        roundTripURL = nil
        savedToRoundTrip = false
        sourceURL = url
        sourceProperties = ImageWriter.readProperties(from: url)
        sourceImage = image
        errorMessage = nil
        runSuggestion()
        process()
    }

    /// Load an image and remember its source URL so that the user can save
    /// the desqueezed result back to the same path (round-trip with Lightroom).
    func loadForRoundTrip(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let image: NSImage?
        let data: Data
        do {
            data = try Data(contentsOf: url)
            image = NSImage(data: data)
        } catch {
            errorMessage = "Could not read file: \(error.localizedDescription)"
            return
        }
        guard let loaded = image else {
            errorMessage = "Could not decode image from \(url.lastPathComponent)."
            return
        }

        roundTripURL = url
        savedToRoundTrip = false
        sourceURL = url
        sourceProperties = ImageWriter.readProperties(from: data)
        sourceImage = loaded
        errorMessage = nil
        suggestedFactor = nil
        suggestedPreset = nil
        isEstimating = false
        process()
    }

    func loadImage(_ image: NSImage) {
        roundTripURL = nil
        savedToRoundTrip = false
        sourceURL = nil
        // No backing file, so try the image's own data for metadata.
        sourceProperties = image.tiffRepresentation.flatMap(ImageWriter.readProperties(from:))
        sourceImage = image
        errorMessage = nil
        runSuggestion()
        process()
    }

    func clearImage() {
        sourceImage = nil
        processedImage = nil
        errorMessage = nil
        suggestedFactor = nil
        suggestedPreset = nil
        isEstimating = false
        roundTripURL = nil
        savedToRoundTrip = false
        sourceURL = nil
        sourceProperties = nil
    }

    /// Save the desqueezed image back to the original round-trip URL so that
    /// the host application (Lightroom) re-imports the modified file.
    func saveBackToHost() async -> Bool {
        guard let url = roundTripURL else { return false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ok = await exportImage(to: url)
        if ok { savedToRoundTrip = true }
        return ok
    }

    func applySuggestion() {
        guard let factor = suggestedFactor else { return }
        let preset = SqueezeEstimator.suggestedPreset(for: factor)
        selectedPreset = preset
        if preset == .custom {
            customFactor = String(format: "%.2f", factor)
        }
        process()
    }

    private func runSuggestion() {
        guard let source = sourceImage else { return }
        suggestedFactor = nil
        suggestedPreset = nil
        isEstimating = true
        Task { [weak self] in
            let factor = await SqueezeEstimator.estimateFactor(for: source)
            await MainActor.run {
                guard let self else { return }
                self.suggestedFactor = factor
                self.suggestedPreset = factor.map(SqueezeEstimator.suggestedPreset(for:))
                self.isEstimating = false
            }
        }
    }

    func process() {
        guard let source = sourceImage else { return }
        isProcessing = true
        let factor = activeFactor

        Task.detached(priority: .userInitiated) {
            let result = Self.desqueeze(image: source, factor: factor)
            await MainActor.run {
                self.processedImage = result
                self.isProcessing = false
                if result == nil {
                    self.errorMessage = "Could not desqueeze this image — unsupported pixel format."
                }
            }
        }
    }

    nonisolated private static func desqueeze(image: NSImage, factor: CGFloat) -> NSImage? {
        guard let cgSrc = cgImage(from: image) else { return nil }

        let srcW = CGFloat(cgSrc.width)
        let srcH = CGFloat(cgSrc.height)
        let dstW = Int(srcW * factor)
        let dstH = Int(srcH)

        // Try to preserve the source's pixel format. Fall back to a known-good
        // 8-bit sRGB premultiplied context for unusual formats (16-bit TIFFs,
        // CMYK, indexed, etc.) that CGContext rejects.
        if let stretched = drawStretched(cgSrc, width: dstW, height: dstH, useSourceFormat: true)
            ?? drawStretched(cgSrc, width: dstW, height: dstH, useSourceFormat: false) {
            return NSImage(cgImage: stretched, size: CGSize(width: dstW, height: dstH))
        }
        return nil
    }

    nonisolated private static func cgImage(from image: NSImage) -> CGImage? {
        if let direct = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return direct
        }
        // NSImage built from Data sometimes only exposes a bitmap rep.
        for rep in image.representations {
            if let bmp = rep as? NSBitmapImageRep, let cg = bmp.cgImage {
                return cg
            }
        }
        return nil
    }

    nonisolated private static func drawStretched(
        _ cgSrc: CGImage,
        width: Int,
        height: Int,
        useSourceFormat: Bool
    ) -> CGImage? {
        let colorSpace: CGColorSpace
        let bitsPerComponent: Int
        let bitmapInfo: UInt32

        if useSourceFormat {
            colorSpace = cgSrc.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
            bitsPerComponent = cgSrc.bitsPerComponent
            bitmapInfo = cgSrc.bitmapInfo.rawValue
        } else {
            colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
            bitsPerComponent = 8
            bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        }

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cgSrc, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    func exportImage(to url: URL) async -> Bool {
        guard let image = processedImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return false }

        let utType = ImageWriter.fileType(forExtension: url.pathExtension)
        let jpegQuality: CGFloat? = utType == .jpeg ? 0.92 : nil
        nonisolated(unsafe) let props = sourceProperties

        let ok = await Task.detached(priority: .userInitiated) {
            ImageWriter.write(cgImage, to: url, utType: utType,
                              sourceProperties: props, jpegQuality: jpegQuality)
        }.value

        if !ok {
            errorMessage = "Export failed: could not encode image."
        }
        return ok
    }
}
