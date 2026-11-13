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
            applyMatte()
        }
    }
    var matteSize: MatteSize {
        didSet {
            UserDefaults.standard.set(matteSize.rawValue, forKey: Self.matteSizeKey)
            applyMatte()
        }
    }
    private static let matteKey = "export.addsMatte"
    private static let matteSizeKey = "export.matteSize"

    enum MatteSize: String, CaseIterable, Identifiable {
        case small, medium
        var id: String { rawValue }
        var matte: Matte { self == .small ? .small : .medium }
        var label: String { self == .small ? "Small · 2%" : "Medium · 5%" }
    }

    private func applyMatte() {
        session.matte = addsMatte ? matteSize.matte : nil
    }

    /// Whether to look through recent photos for ones that need correcting.
    /// Off until the owner turns it on, because it reads the library.
    var findsSqueezed: Bool {
        didSet {
            UserDefaults.standard.set(findsSqueezed, forKey: Self.findKey)
            if findsSqueezed {
                Task { await startFinding() }
            } else {
                found = []
            }
        }
    }
    /// Recent photos that look squeezed and have not been dealt with.
    private(set) var found: [RecentScanner.Found] = []
    private(set) var isScanning = false
    /// Which library photo each queued item came from, when it came from a scan.
    private var libraryIDs: [Batch.Item.ID: String] = [:]
    /// The same, for the photo open in the editor.
    private var openLibraryID: String?
    private static let correctionsKey = "detect.corrections"
    private static let findKey = "detect.enabled"
    private static let handledKey = "detect.handled"
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
        // Medium is what the matte was before there was a choice.
        matteSize = UserDefaults.standard.string(forKey: Self.matteSizeKey).flatMap(MatteSize.init) ?? .medium
        findsSqueezed = UserDefaults.standard.bool(forKey: Self.findKey)
        applyMatte()
    }

    // MARK: - Finding squeezed photos

    /// Photos already corrected, dismissed or examined and found ordinary.
    private var handled: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? [])
    }

    private func remember(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        var all = UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? []
        all.append(contentsOf: ids)
        // Only recent photos are ever scanned, so old entries can go.
        UserDefaults.standard.set(Array(all.suffix(1000)), forKey: Self.handledKey)
    }

    /// Photos the owner has corrected, kept so that others from the same
    /// session can be recognised.
    private var corrections: [PictureSignals.Correction] {
        UserDefaults.standard.data(forKey: Self.correctionsKey)
            .flatMap { try? JSONDecoder().decode([PictureSignals.Correction].self, from: $0) } ?? []
    }

    /// Notes that a library photo was corrected at `factor`.
    private func learn(from libraryID: String?, factor: Double) {
        guard findsSqueezed, RecentScanner.hasAccess, let libraryID,
              let correction = RecentScanner.correction(for: libraryID, factor: factor) else { return }
        remember([libraryID])
        let all = Array((corrections + [correction]).suffix(200))
        UserDefaults.standard.set(try? JSONEncoder().encode(all), forKey: Self.correctionsKey)
    }

    private func startFinding() async {
        guard await RecentScanner.requestAccess() else {
            findsSqueezed = false
            notice = Notice(text: "StillScope needs access to your photos to find squeezed ones. Allow it in Settings › Privacy › Photos.", isError: true)
            return
        }
        await scanRecent()
    }

    /// Looks for squeezed photos, when that is switched on and nothing is open.
    func scanRecent() async {
        guard findsSqueezed, RecentScanner.hasAccess, !isScanning, !hasContent else { return }
        isScanning = true
        defer { isScanning = false }
        let skipping = handled, learned = corrections
        let result = await Task.detached(priority: .utility) {
            await RecentScanner.scan(skipping: skipping, corrections: learned)
        }.value
        remember(result.ordinary)
        found = result.found
    }

    /// Puts the photos the scan found into the batch, each with the factor
    /// the scan read for it.
    func queueFound() {
        let photos = Array(found.prefix(Self.batchLimit))
        guard !photos.isEmpty else { return }
        notice = nil
        suggestion = nil
        thumbnailing?.cancel()
        thumbnails = [:]
        libraryIDs = [:]
        openLibraryID = nil
        session.close()
        batch.clear()

        var queued: [(Batch.Item.ID, String)] = []
        for photo in photos {
            let libraryID = photo.id
            let id = batch.add(name: photo.name) {
                guard let data = await RecentScanner.data(for: libraryID, allowNetwork: true) else {
                    throw CoreImageRenderer.Failure.undecodable
                }
                return data
            }
            if let factor = photo.factor {
                batch.setSqueeze(Squeeze(factor: factor), for: id)
            }
            libraryIDs[id] = libraryID
            queued.append((id, libraryID))
        }
        found = []

        thumbnailing = Task {
            for (id, libraryID) in queued {
                guard !Task.isCancelled else { return }
                guard let data = await RecentScanner.data(for: libraryID, allowNetwork: true),
                      let thumbnail = await Thumbnailer.thumbnail(of: data, longestEdge: 900),
                      !Task.isCancelled
                else { continue }
                thumbnails[id] = thumbnail
            }
        }
    }

    /// Takes a photo out of the batch. One the scan found is not offered again.
    func removeFromBatch(_ id: Batch.Item.ID) {
        if let libraryID = libraryIDs.removeValue(forKey: id) { remember([libraryID]) }
        thumbnails[id] = nil
        batch.remove(id)
    }

    // MARK: - Intake

    /// An image file another app asked StillScope to open.
    func open(_ url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            notice = Notice(text: "That file could not be opened.", isError: true)
            return
        }
        notice = nil
        thumbnailing?.cancel()
        thumbnails = [:]
        libraryIDs = [:]
        openLibraryID = nil
        batch.clear()
        await session.open(data)
        suggestion = await FaceEstimator.suggestion(for: data)
    }

    func take(_ picked: [PhotosPickerItem]) async {
        notice = nil
        suggestion = nil
        thumbnailing?.cancel()
        thumbnails = [:]
        libraryIDs = [:]
        openLibraryID = nil
        guard !picked.isEmpty else { return }

        if picked.count == 1 {
            batch.clear()
            guard let data = try? await picked[0].loadTransferable(type: Data.self) else {
                notice = Notice(text: "That photo could not be loaded.", isError: true)
                return
            }
            openLibraryID = picked[0].itemIdentifier
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
                libraryIDs[id] = item.itemIdentifier
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
        libraryIDs = [:]
        openLibraryID = nil
        suggestion = nil
        notice = nil
    }

    // MARK: - Output

    func saveToLibrary() async {
        do {
            let name = String(format: "desqueeze_%.2fx.jpg", session.squeeze.factor)
            try await PhotoLibraryWriter.save(jpeg: try await session.export(), named: name)
            learn(from: openLibraryID, factor: session.squeeze.factor)
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
        // A library photo that is now saved has been dealt with, and says
        // something about the photos taken alongside it.
        for item in batch.items where item.state == .done {
            learn(from: libraryIDs[item.id], factor: (item.squeeze ?? session.squeeze).factor)
        }
        remember(batch.items.filter { $0.state == .done }.compactMap { libraryIDs[$0.id] })
        let failed = batch.items.count - batch.finishedCount
        notice = failed == 0
            ? Notice(text: "\(batch.finishedCount) saved to your library.", isError: false)
            : Notice(text: "\(failed) of \(batch.items.count) could not be saved. Run again to retry them.", isError: true)
    }
}
