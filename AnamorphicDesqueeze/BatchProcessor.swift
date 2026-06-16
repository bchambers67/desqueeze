import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// One file in a batch. Owns its detected factor and any manual override.
@MainActor
final class BatchItem: ObservableObject, Identifiable {
    let id = UUID()
    let sourceURL: URL
    /// Filename to use when writing the output (preserved across temp-copy hops).
    let displayName: String

    @Published var thumbnail: NSImage?
    @Published var detectedFactor: CGFloat?
    @Published var detectionDone: Bool = false

    @Published var selectedPreset: SqueezePreset = .x150
    @Published var customFactor: String = "1.33"

    @Published var status: Status = .pending
    @Published var errorMessage: String?

    enum Status: Equatable {
        case pending
        case processing
        case completed(URL)
        case failed(String)
    }

    init(sourceURL: URL, displayName: String) {
        self.sourceURL = sourceURL
        self.displayName = displayName
    }

    var activeFactor: CGFloat {
        selectedPreset == .custom
            ? CGFloat(Double(customFactor) ?? 1.33)
            : (selectedPreset.factor ?? 1.50)
    }

    /// True if the user has moved the picker away from the auto-detected suggestion.
    var isOverridden: Bool {
        guard let detected = detectedFactor else { return false }
        let suggested = SqueezeEstimator.suggestedPreset(for: detected)
        if suggested != selectedPreset { return true }
        if suggested == .custom {
            return abs(activeFactor - detected) > 0.005
        }
        return false
    }

    func resetToAutoDetected() {
        guard let detected = detectedFactor else { return }
        selectedPreset = SqueezeEstimator.suggestedPreset(for: detected)
        if selectedPreset == .custom {
            customFactor = String(format: "%.2f", detected)
        }
    }
}

@MainActor
final class BatchProcessor: ObservableObject {
    @Published private(set) var items: [BatchItem] = []
    @Published private(set) var isExporting: Bool = false
    @Published private(set) var currentExportIndex: Int = 0
    @Published var errorMessage: String?

    @Published var bulkPreset: SqueezePreset = .x150
    @Published var bulkCustomFactor: String = "1.33"

    private var exportTask: Task<Void, Never>?

    var isEmpty: Bool { items.isEmpty }

    var completedCount: Int {
        items.filter {
            if case .completed = $0.status { return true } else { return false }
        }.count
    }

    var failedCount: Int {
        items.filter {
            if case .failed = $0.status { return true } else { return false }
        }.count
    }

    var detectedCount: Int {
        items.filter { $0.detectedFactor != nil }.count
    }

    func add(urls: [URL]) {
        for url in urls {
            let item = BatchItem(sourceURL: url, displayName: url.lastPathComponent)
            items.append(item)
            loadAndDetect(item)
        }
    }

    /// Apply the bulk preset/factor to every item in the batch, including ones
    /// that have already been auto-detected.
    func applyBulkFactorToAll() {
        for item in items {
            item.selectedPreset = bulkPreset
            if bulkPreset == .custom {
                item.customFactor = bulkCustomFactor
            }
        }
    }

    /// Revert every item back to its auto-detected suggestion.
    /// Items that had no detection are left as-is.
    func resetAllToAutoDetected() {
        for item in items {
            item.resetToAutoDetected()
        }
    }

    func remove(_ item: BatchItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        cancelExport()
        items.removeAll()
        errorMessage = nil
    }

    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        isExporting = false
    }

    func exportAll(to folder: URL) {
        guard !isExporting else { return }
        isExporting = true
        currentExportIndex = 0
        errorMessage = nil
        let snapshot = items
        exportTask = Task { [weak self] in
            for (idx, item) in snapshot.enumerated() {
                if Task.isCancelled { break }
                if case .completed = item.status { continue }
                item.status = .processing
                self?.currentExportIndex = idx
                let result = await Self.processOne(item: item, folder: folder)
                item.status = result.status
                item.errorMessage = result.error
            }
            self?.isExporting = false
            self?.exportTask = nil
        }
    }

    private func loadAndDetect(_ item: BatchItem) {
        let url = item.sourceURL
        Task.detached(priority: .userInitiated) {
            guard let image = NSImage(contentsOf: url) else {
                await MainActor.run {
                    item.detectionDone = true
                    item.errorMessage = "Could not load image"
                }
                return
            }
            let thumbCG = Self.makeThumbnail(from: image)
            let factor = await SqueezeEstimator.estimateFactor(for: image)
            await MainActor.run {
                if let cg = thumbCG {
                    item.thumbnail = NSImage(
                        cgImage: cg,
                        size: NSSize(width: cg.width, height: cg.height)
                    )
                }
                item.detectedFactor = factor
                if let f = factor {
                    item.selectedPreset = SqueezeEstimator.suggestedPreset(for: f)
                    if item.selectedPreset == .custom {
                        item.customFactor = String(format: "%.2f", f)
                    }
                }
                item.detectionDone = true
            }
        }
    }

    nonisolated private static func makeThumbnail(from image: NSImage) -> CGImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let targetW: CGFloat = 96
        let scale = targetW / CGFloat(cg.width)
        let w = Int(targetW)
        let h = max(1, Int(CGFloat(cg.height) * scale))
        let colorSpace = cg.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: cg.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: cg.bitmapInfo.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    private struct Outcome {
        let status: BatchItem.Status
        let error: String?
    }

    private static func processOne(item: BatchItem, folder: URL) async -> Outcome {
        let sourceURL = item.sourceURL
        let displayName = item.displayName
        let factor = item.activeFactor
        return await Task.detached(priority: .userInitiated) {
            guard let image = NSImage(contentsOf: sourceURL),
                  let cgSrc = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else {
                return Outcome(status: .failed("Could not load image"),
                               error: "Could not load image")
            }
            let srcW = CGFloat(cgSrc.width)
            let srcH = CGFloat(cgSrc.height)
            let dstW = Int(srcW * factor)
            let dstH = Int(srcH)
            let colorSpace = cgSrc.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

            guard let ctx = CGContext(
                data: nil,
                width: dstW, height: dstH,
                bitsPerComponent: cgSrc.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgSrc.bitmapInfo.rawValue
            ) else {
                return Outcome(status: .failed("Could not create bitmap context"),
                               error: "Could not create bitmap context")
            }
            ctx.interpolationQuality = .high
            ctx.draw(cgSrc, in: CGRect(x: 0, y: 0, width: dstW, height: dstH))

            guard let stretched = ctx.makeImage() else {
                return Outcome(status: .failed("Could not render image"),
                               error: "Could not render image")
            }

            let ext = (displayName as NSString).pathExtension.isEmpty
                ? "jpg"
                : (displayName as NSString).pathExtension
            let base = (displayName as NSString).deletingPathExtension
            let outURL = folder.appendingPathComponent("\(base)_desqueezed.\(ext)")

            let utType = ImageWriter.fileType(forExtension: ext)
            let jpegQuality: CGFloat? = utType == .jpeg ? 0.92 : nil
            // Carry the source's metadata (capture date, camera, lens, GPS…)
            // onto the desqueezed output.
            let sourceProps = ImageWriter.readProperties(from: sourceURL)

            guard ImageWriter.write(stretched, to: outURL, utType: utType,
                                    sourceProperties: sourceProps, jpegQuality: jpegQuality)
            else {
                return Outcome(status: .failed("Could not encode image"),
                               error: "Could not encode image")
            }
            return Outcome(status: .completed(outURL), error: nil)
        }.value
    }
}
