import SwiftUI
import Observation

/// Document state for one image.
///
/// Deliberately an `@Observable` reference type owned by the app, not `@State`
/// inside a view. Folding and unfolding the Duo is a resize: SwiftUI tears down
/// and rebuilds the view tree around the new size class, and anything held in
/// view-local state goes with it. Holding state here is what makes the fold
/// lossless.
@Observable
@MainActor
final class EditorModel {

    // MARK: - Source

    /// The original file bytes, kept so export can re-render at full size
    /// rather than upscaling the screen-sized preview.
    private(set) var sourceData: Data?
    private(set) var sourcePixelSize: CGSize?

    // MARK: - Correction

    var preset: SqueezePreset = .x200 {
        didSet { if preset != oldValue { schedulePreview() } }
    }

    /// Free-entry factor, used when `preset == .custom`.
    var customFactor: String = "1.33" {
        didSet { if preset == .custom, customFactor != oldValue { schedulePreview() } }
    }

    var factor: Double {
        if let f = preset.factor { return f }
        let parsed = Double(customFactor) ?? 1.33
        // Clamp to the plausible anamorphic range rather than trusting input.
        return min(max(parsed, 1.0), 3.0)
    }

    // MARK: - Output

    private(set) var preview: UIImage?
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    /// Dimensions the export will have, derived rather than measured, so the
    /// readout is correct before any render completes.
    var outputPixelSize: CGSize? {
        guard let s = sourcePixelSize else { return nil }
        return CGSize(width: (s.width * factor).rounded(), height: s.height)
    }

    var aspectRatio: Double? {
        guard let s = outputPixelSize, s.height > 0 else { return nil }
        return s.width / s.height
    }

    var hasImage: Bool { sourceData != nil }

    // MARK: - Machinery

    private let service = DesqueezeService()
    /// The in-flight preview render, cancelled when the factor changes again.
    private var previewTask: Task<Void, Never>?
    /// Longest edge to rasterise for on-screen preview.
    private var previewBudget: CGFloat = 2_400

    /// The Duo's inner display is markedly larger than the outer one; the
    /// preview budget follows whatever surface is actually showing so the
    /// folded state does not pay for pixels it cannot display.
    func updatePreviewBudget(forLongestEdge points: CGFloat, scale: CGFloat) {
        let target = max(1_200, points * scale * 1.25)
        guard abs(target - previewBudget) > 200 else { return }
        previewBudget = target
        schedulePreview()
    }

    func load(data: Data) {
        sourceData = data
        errorMessage = nil

        Task {
            if let size = await measure(data) { sourcePixelSize = size }
            schedulePreview()
        }
    }

    private func measure(_ data: Data) async -> CGSize? {
        try? await service.makeImage(from: data).extent.size
    }

    func clear() {
        previewTask?.cancel()
        sourceData = nil
        sourcePixelSize = nil
        preview = nil
        errorMessage = nil
        isWorking = false
    }

    /// Re-renders the preview, superseding any render already running.
    private func schedulePreview() {
        guard let data = sourceData else { return }
        previewTask?.cancel()

        let factor = self.factor
        let budget = self.previewBudget

        previewTask = Task { [service] in
            // Coalesce the bursts that come from dragging a slider or typing a
            // factor, so only the settled value is rendered.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }

            isWorking = true
            defer { isWorking = false }

            do {
                let image = try await service.process(
                    data: data, factor: factor, maxDimension: budget
                )
                guard !Task.isCancelled else { return }
                preview = image
                errorMessage = nil
            } catch is CancellationError {
                // Superseded by a newer render; leave the previous frame up.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Full-resolution JPEG of the corrected frame.
    func exportJPEG() async throws -> Data {
        guard let data = sourceData else { throw DesqueezeService.Failure.undecodable }
        return try await service.encodeJPEG(data: data, factor: factor)
    }
}
