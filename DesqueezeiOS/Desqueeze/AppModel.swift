import DesqueezeCore
import PhotosUI
import SwiftUI

typealias Session = EditorSession<CoreImageRenderer>
typealias Batch = BatchQueue<CoreImageRenderer>

/// Everything that must outlive the view tree.
///
/// Folding or unfolding an iPhone Duo rebuilds the views around a new size
/// class. The session, the batch and what the picker handed over all live
/// here, owned by the app, so that rebuild loses nothing.
@MainActor @Observable
final class AppModel {
    let session: Session
    let batch: Batch

    /// A factor read from the faces in the open photo, when there is one.
    private(set) var suggestion: Double?
    /// A preview of each queued photo, as shot. Absent until it has loaded.
    private(set) var thumbnails: [Batch.Item.ID: CoreImageRenderer.Frame] = [:]
    private var thumbnailing: Task<Void, Never>?
    private(set) var notice: Notice?

    // Held here rather than in a view: a fold rebuilds the views, and an open
    // inspector or a running save must not reset when it does.
    var isInspecting = false
    var isChoosingFactor = false
    /// The docked slider on an open Duo held sideways; shown until dismissed.
    var isFactorDockShown = true
    var isShowingSettings = false

    /// Settings. Each is kept between launches.
    var addsMatte: Bool {
        didSet {
            UserDefaults.standard.set(addsMatte, forKey: Self.matteKey)
            session.matte = addsMatte ? .standard : nil
        }
    }
    private static let matteKey = "export.addsMatte"
    var sharedFile: SharedFile?
    private(set) var isWorking = false

    struct Notice: Equatable {
        var text: String
        var isError: Bool
    }

    /// One photo opens in the editor; several become a batch.
    var mode: Mode { batch.items.isEmpty ? .single : .batch }
    enum Mode { case single, batch }

    static let batchLimit = 36

    /// Whether there is anything to act on: an open photo or a queued batch.
    var hasContent: Bool { session.hasPhoto || !batch.items.isEmpty }

    init() {
        let renderer = CoreImageRenderer()
        session = Session(renderer: renderer)
        batch = Batch(renderer: renderer)
        addsMatte = UserDefaults.standard.bool(forKey: Self.matteKey)
        session.matte = addsMatte ? .standard : nil
    }

    // MARK: - Intake

    func take(_ picked: [PhotosPickerItem]) async {
        notice = nil
        suggestion = nil
        thumbnailing?.cancel()
        thumbnails = [:]
        guard !picked.isEmpty else { return }

        if picked.count == 1 {
            batch.clear()
            guard let data = try? await picked[0].loadTransferable(type: Data.self) else {
                notice = Notice(text: "That photo could not be loaded.", isError: true)
                return
            }
            await session.open(data)
            suggestion = await FaceEstimator.suggestion(for: data)
        } else {
            session.close()
            batch.clear()
            var queued: [(Batch.Item.ID, PhotosPickerItem)] = []
            for (index, item) in picked.prefix(Self.batchLimit).enumerated() {
                // The picker gives no filename without library access, which
                // this app does not ask for; number them instead.
                let id = batch.add(name: String(format: "Photo-%02d.jpg", index + 1)) {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw CoreImageRenderer.Failure.undecodable
                    }
                    return data
                }
                queued.append((id, item))
            }
            // One at a time, so only one full-size photo is in memory.
            thumbnailing = Task {
                for (id, item) in queued {
                    guard !Task.isCancelled else { return }
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let thumbnail = await Thumbnailer.thumbnail(of: data, longestEdge: 900),
                          !Task.isCancelled
                    else { continue }
                    thumbnails[id] = thumbnail
                }
            }
        }
    }

    func useSuggestion() async {
        guard let suggestion else { return }
        if let preset = SqueezePreset.nearest(to: suggestion) {
            await session.choose(preset)
        } else {
            await session.type(String(format: "%.2f", suggestion))
        }
    }

    /// A factor from the slider. On a stop point it is that preset; anywhere
    /// else it is a custom factor.
    func use(factor: Double) async {
        guard abs(factor - session.squeeze.factor) > 0.001 else { return }
        let onStop = SqueezePreset.selectable.first { preset in
            preset.factor.map { abs($0 - factor) < 0.005 } ?? false
        }
        if let onStop {
            await session.choose(onStop)
        } else {
            await session.type(String(format: "%.2f", factor))
        }
    }

    /// Runs one output action at a time, and says so while it does.
    func perform(_ action: @MainActor () async -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        await action()
    }

    func reset() {
        isInspecting = false
        sharedFile = nil
        session.close()
        batch.clear()
        thumbnailing?.cancel()
        thumbnails = [:]
        suggestion = nil
        notice = nil
    }

    // MARK: - Output

    func saveToLibrary() async {
        do {
            let name = String(format: "desqueeze_%.2fx.jpg", session.squeeze.factor)
            try await PhotoLibraryWriter.save(jpeg: try await session.export(), named: name)
            notice = Notice(text: "Saved to your library.", isError: false)
        } catch {
            notice = Notice(text: error.localizedDescription, isError: true)
        }
    }

    /// Renders the export to a temporary file and hands it to the share sheet.
    func share() async {
        do {
            let data = try await session.export()
            let name = String(format: "desqueeze_%.2fx.jpg", session.squeeze.factor)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            sharedFile = SharedFile(url: url)
        } catch {
            notice = Notice(text: error.localizedDescription, isError: true)
        }
    }

    func runBatch() async {
        notice = nil
        await batch.run(squeeze: session.squeeze, matte: session.matte) { name, file in
            try await PhotoLibraryWriter.save(jpeg: file, named: name)
        }
        let failed = batch.items.count - batch.finishedCount
        notice = failed == 0
            ? Notice(text: "\(batch.finishedCount) saved to your library.", isError: false)
            : Notice(text: "\(failed) of \(batch.items.count) could not be saved. Run again to retry them.", isError: true)
    }
}
