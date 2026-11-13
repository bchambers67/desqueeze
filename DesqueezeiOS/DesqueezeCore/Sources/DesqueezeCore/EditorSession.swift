import Foundation
import Observation

/// The one thing the session cannot do itself: turn bytes into pictures.
/// Core Image satisfies this in the app; a fake does in tests.
public protocol FrameRenderer: Sendable {
    associatedtype Frame: Sendable
    func size(of source: Data) async throws -> PixelSize
    /// The corrected frame, scaled so its longest edge is at most `longestEdge`.
    func preview(of source: Data, squeeze: Squeeze, longestEdge: Int) async throws -> Frame
    /// The corrected frame at full size, encoded as JPEG.
    func export(_ source: Data, squeeze: Squeeze) async throws -> Data
}

/// One photograph being corrected.
///
/// Owned above the view tree on purpose. Folding or unfolding an iPhone Duo is
/// a resize that rebuilds the views around a new size class; state held here
/// is what survives it.
@MainActor @Observable
public final class EditorSession<Renderer: FrameRenderer> {
    public private(set) var sourceSize: PixelSize?
    public private(set) var preview: Renderer.Frame?
    public private(set) var squeeze = Squeeze(factor: 2.0)
    public private(set) var preset: SqueezePreset = .x200
    /// Why the last open or render did not work, in words fit to show.
    public private(set) var failure: String?

    /// What was last typed into the custom field, kept so the field can show it.
    public private(set) var typedFactor = ""
    public private(set) var typedFactorIsValid = true

    public private(set) var isRendering = false

    public var hasPhoto: Bool { source != nil }

    public var outputSize: PixelSize? { sourceSize.map(squeeze.outputSize(for:)) }

    private let renderer: Renderer
    private var source: Data?
    private var longestEdge = 2400
    /// Bumped per render request; a result is only shown if still the newest.
    private var generation = 0
    private var renderLoopIsRunning = false

    public init(renderer: Renderer) { self.renderer = renderer }

    public func open(_ data: Data) async {
        generation += 1
        let mine = generation
        do {
            let size = try await renderer.size(of: data)
            // Closed, or another photo opened, while this one was loading.
            guard mine == generation else { return }
            source = data
            sourceSize = size
            failure = nil
            await render()
        } catch {
            guard mine == generation else { return }
            source = nil
            sourceSize = nil
            preview = nil
            failure = error.localizedDescription
        }
    }

    public func choose(_ preset: SqueezePreset) async {
        guard let factor = preset.factor else { return }
        self.preset = preset
        squeeze = Squeeze(factor: factor)
        await render()
    }

    public struct NothingOpen: Error {}

    /// The corrected photo at full size, as JPEG, with capture metadata kept.
    public func export() async throws -> Data {
        guard let source, let size = outputSize else { throw NothingOpen() }
        let jpeg = try await renderer.export(source, squeeze: squeeze)
        return CaptureMetadata.carry(from: source, onto: jpeg, size: size)
    }

    /// The display showing the preview changed size, as when a Duo is folded
    /// or opened. Renders are sized to the surface that will show them.
    public func fit(longestEdge: Int) async {
        guard longestEdge != self.longestEdge else { return }
        self.longestEdge = longestEdge
        await render()
    }

    /// A factor entered by hand. Text that is not a number changes nothing
    /// but the validity flag, so the last good frame stays on screen.
    public func type(_ text: String) async {
        typedFactor = text
        preset = .custom
        guard let typed = Squeeze(typed: text) else {
            typedFactorIsValid = false
            return
        }
        typedFactorIsValid = true
        squeeze = typed
        await render()
    }

    /// The longest edge an inspection frame may have. 8192² RGBA is a quarter
    /// of a gigabyte; past that a single bitmap is not a reasonable ask.
    public static var inspectionLimit: Int { 8192 }

    /// A frame for close inspection: full size where that fits in memory,
    /// otherwise as large as is sensible.
    public func inspectionFrame() async throws -> Renderer.Frame {
        guard let source, let size = outputSize else { throw NothingOpen() }
        let edge = min(max(size.width, size.height), Self.inspectionLimit)
        return try await renderer.preview(of: source, squeeze: squeeze, longestEdge: edge)
    }

    public func close() {
        generation += 1
        source = nil
        sourceSize = nil
        preview = nil
        failure = nil
        isRendering = false
    }

    /// Renders the newest request, and only the newest.
    ///
    /// A slider asks for a render on every step. Requests that arrive while
    /// one is running do not queue behind it: they are folded into a single
    /// follow-up for whatever the factor is by then, so the preview is never
    /// more than one render behind the thumb.
    private func render() async {
        guard source != nil else { return }
        generation += 1
        guard !renderLoopIsRunning else { return }
        renderLoopIsRunning = true
        isRendering = true
        defer {
            renderLoopIsRunning = false
            isRendering = false
        }
        while let source {
            let mine = generation
            do {
                let frame = try await renderer.preview(of: source, squeeze: squeeze, longestEdge: longestEdge)
                // Superseded while it ran: drop it and go round for the newest.
                guard mine == generation else { continue }
                preview = frame
                failure = nil
            } catch {
                guard mine == generation else { continue }
                failure = error.localizedDescription
            }
            return
        }
    }
}
