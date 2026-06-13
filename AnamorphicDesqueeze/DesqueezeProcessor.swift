import AppKit
import CoreGraphics

enum SqueezePreset: String, CaseIterable, Identifiable {
    case x133  = "1.33×"
    case x150  = "1.50×"
    case x200  = "2.00×"
    case custom = "Custom"

    var id: String { rawValue }

    var factor: CGFloat? {
        switch self {
        case .x133:   return 1.33
        case .x150:   return 1.50
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

    var isRoundTrip: Bool { roundTripURL != nil }

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
        sourceImage = image
        errorMessage = nil
        runSuggestion()
        process()
    }

    /// Load an image and remember its source URL so that the user can save
    /// the desqueezed result back to the same path (round-trip with Lightroom).
    func loadForRoundTrip(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            errorMessage = "Could not load image from that file."
            return
        }
        roundTripURL = url
        savedToRoundTrip = false
        sourceImage = image
        errorMessage = nil
        runSuggestion()
        process()
    }

    func loadImage(_ image: NSImage) {
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
    }

    /// Save the desqueezed image back to the original round-trip URL so that
    /// the host application (Lightroom) re-imports the modified file.
    func saveBackToHost() async -> Bool {
        guard let url = roundTripURL else { return false }
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
            }
        }
    }

    nonisolated private static func desqueeze(image: NSImage, factor: CGFloat) -> NSImage? {
        guard let cgSrc = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let srcW = CGFloat(cgSrc.width)
        let srcH = CGFloat(cgSrc.height)
        let dstW  = Int(srcW * factor)
        let dstH  = Int(srcH)

        let colorSpace = cgSrc.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        guard let ctx = CGContext(
            data: nil,
            width: dstW,
            height: dstH,
            bitsPerComponent: cgSrc.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: cgSrc.bitmapInfo.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cgSrc, in: CGRect(x: 0, y: 0, width: dstW, height: dstH))

        guard let stretched = ctx.makeImage() else { return nil }
        return NSImage(cgImage: stretched, size: CGSize(width: dstW, height: dstH))
    }

    func exportImage(to url: URL) async -> Bool {
        guard let image = processedImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return false }

        let ext = url.pathExtension.lowercased()
        let fileType: NSBitmapImageRep.FileType
        switch ext {
        case "png":              fileType = .png
        case "tif", "tiff":      fileType = .tiff
        default:                 fileType = .jpeg
        }
        let compression: CGFloat? = fileType == .jpeg ? 0.92 : nil

        do {
            try await Task.detached(priority: .userInitiated) {
                let bmp = NSBitmapImageRep(cgImage: cgImage)
                let props: [NSBitmapImageRep.PropertyKey: Any] =
                    compression.map { [.compressionFactor: $0] } ?? [:]
                guard let data = bmp.representation(using: fileType, properties: props) else {
                    throw NSError(domain: "Desqueeze", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Could not encode image."])
                }
                try data.write(to: url)
            }.value
            return true
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            return false
        }
    }
}
