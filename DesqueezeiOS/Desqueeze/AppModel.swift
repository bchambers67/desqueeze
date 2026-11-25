import DesqueezeCore
import PhotosUI
import SwiftUI
import UIKit

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
    /// What the status chip says. Every notice leaves by itself after
    /// `noticeLifetime`, or sooner when something replaces it.
    private(set) var notice: Notice? { didSet { scheduleNoticeExpiry() } }
    private var noticeExpiry: Task<Void, Never>?
    private var lastTally = RecentScanner.Tally()
    static let noticeLifetime: Duration = .seconds(5)

    // Held here rather than in a view: a fold rebuilds the views, and an open
    // inspector or a running save must not reset when it does.
    var isInspecting = false
    /// Whether the factor panel is popped out over the photograph. This is
    /// for the layouts with a bottom bar. On an open Duo held sideways the
    /// panel has a place of its own and is always there.
    var isFactorPanelOpen = false

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
    private static let dealtWithKey = "detect.dealtWith"
    private static let ordinaryKey = "detect.ordinary"
    var sharedFile: SharedFile?
    private(set) var isWorking = false

    struct Notice: Equatable {
        var text: String
        var isError: Bool
        /// Work under way rather than a result: shown with a spinner.
        var isBusy = false
    }

    private func scheduleNoticeExpiry() {
        noticeExpiry?.cancel()
        guard notice != nil else { return }
        noticeExpiry = Task { [weak self] in
            try? await Task.sleep(for: Self.noticeLifetime)
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    /// One photo opens in the editor; several become a batch.
    var mode: Mode { batch.items.isEmpty ? .single : .batch }
    enum Mode { case single, batch }


    /// Whether there is anything to act on: an open photo or a queued batch.
    var hasContent: Bool { session.hasPhoto || !batch.items.isEmpty }

    /// What the welcome shows right now, or `nil` when it is not on screen.
    var welcome: WelcomePlan?

    static let seenVersionKey = "welcome.seenVersion"
    static let tourSeenKey = "welcome.tourSeen"

    /// The version of the app that is running.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    init() {
        let renderer = CoreImageRenderer()
        session = Session(renderer: renderer)
        batch = Batch(renderer: renderer)
        addsMatte = UserDefaults.standard.bool(forKey: Self.matteKey)
        // Medium is what the matte was before there was a choice.
        matteSize = UserDefaults.standard.string(forKey: Self.matteSizeKey).flatMap(MatteSize.init) ?? .medium
        findsSqueezed = UserDefaults.standard.bool(forKey: Self.findKey)
        applyMatte()
        let plan = WelcomePlan.forLaunch(
            version: Self.version,
            lastSeenVersion: UserDefaults.standard.string(forKey: Self.seenVersionKey),
            tourSeen: UserDefaults.standard.bool(forKey: Self.tourSeenKey))
        welcome = plan.isEmpty ? nil : plan
        #if DEBUG
        Task { await stageShot() }
        #endif
    }

    /// Closing the welcome, finished or skipped, means it is not shown again
    /// for this version, and the tour not at all.
    func finishWelcome() {
        UserDefaults.standard.set(Self.version, forKey: Self.seenVersionKey)
        UserDefaults.standard.set(true, forKey: Self.tourSeenKey)
        welcome = nil
    }

    /// From Settings: show what is new and the tour again.
    func replayWelcome() {
        isShowingSettings = false
        Task {
            // Let the settings sheet leave first; two sheets cannot trade places at once.
            try? await Task.sleep(for: .milliseconds(450))
            welcome = .everything
        }
    }

    // MARK: - Finding squeezed photos

    /// Photos the owner has dealt with: saved, or taken out of the queue.
    /// These are never offered again.
    private var dealtWith: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.dealtWithKey) ?? [])
    }

    /// Photos examined and found ordinary. An everyday check skips them; a
    /// full recheck looks at them again.
    private var foundOrdinary: Set<String> {
        // Before the two lists were kept apart, everything went into one.
        let earlier = UserDefaults.standard.stringArray(forKey: Self.handledKey) ?? []
        return Set(earlier + (UserDefaults.standard.stringArray(forKey: Self.ordinaryKey) ?? []))
    }

    private func remember(_ ids: [String]) {
        append(ids, to: Self.dealtWithKey)
    }

    private func rememberOrdinary(_ ids: [String]) {
        append(ids, to: Self.ordinaryKey)
    }

    private func append(_ ids: [String], to key: String) {
        guard !ids.isEmpty else { return }
        var all = UserDefaults.standard.stringArray(forKey: key) ?? []
        all.append(contentsOf: ids)
        // Only recent photos are ever scanned, so old entries can go.
        UserDefaults.standard.set(Array(all.suffix(1000)), forKey: key)
    }

    /// Photos the owner has corrected, kept so that others from the same
    /// session can be recognised.
    private var corrections: [PictureSignals.Correction] {
        UserDefaults.standard.data(forKey: Self.correctionsKey)
            .flatMap { try? JSONDecoder().decode([PictureSignals.Correction].self, from: $0) } ?? []
    }

    /// Notes that a library photo was corrected at `factor`.
    @discardableResult
    private func learn(from libraryID: String?, factor: Double) -> Bool {
        guard findsSqueezed, RecentScanner.hasAccess, let libraryID,
              let correction = RecentScanner.correction(for: libraryID, factor: factor) else { return false }
        remember([libraryID])
        let all = Array((corrections + [correction]).suffix(200))
        UserDefaults.standard.set(try? JSONEncoder().encode(all), forKey: Self.correctionsKey)
        return true
    }

    private func startFinding() async {
        guard await RecentScanner.requestAccess() else {
            findsSqueezed = false
            notice = Notice(text: "StillScope needs access to your photos to find squeezed ones. Allow it in Settings › Privacy › Photos.", isError: true)
            return
        }
        await scanRecent()
    }

    /// The same check the app makes when it comes forward, asked for by hand,
    /// and it says what it found either way. A full recheck also looks again
    /// at photos an earlier check passed over as ordinary.
    func rescan(everything: Bool = false) async {
        guard findsSqueezed, !isScanning else { return }
        guard RecentScanner.hasAccess else {
            notice = Notice(text: "StillScope needs access to your photos to find squeezed ones. Allow it in Settings › Privacy › Photos.", isError: true)
            return
        }
        if everything {
            UserDefaults.standard.removeObject(forKey: Self.ordinaryKey)
            UserDefaults.standard.removeObject(forKey: Self.handledKey)
        }
        await scanRecent(askedFor: true)
        switch found.count {
        case 0:
            // Say what was seen, so that a miss can be told from a scan that
            // never saw the photos.
            let seen = lastTally
            var text = "None found. Looked at \(seen.total - seen.dealtWith) of \(seen.total)"
            text += seen.dealtWith > 0 ? " (\(seen.dealtWith) done)." : "."
            text += " \(corrections.count) corrected remembered."
            if RecentScanner.hasLimitedAccess { text += " Photos access is limited." }
            notice = Notice(text: text, isError: false)
        case let count where hasContent:
            // The review button is on the empty screen, behind what is open.
            notice = Notice(text: "Found \(count) squeezed photo\(count == 1 ? "" : "s"). Clear to review.", isError: false)
        default:
            notice = nil
        }
    }

    private var scanTask: Task<(found: [RecentScanner.Found], ordinary: [String], tally: RecentScanner.Tally), Never>?

    /// Called when the app stops being the one in front. A scan in the middle of
    /// reading the photo library must not be caught there when the system
    /// suspends the app: a process suspended while it holds the library's files
    /// open is ended by the system (exception code 0xDEAD10CC). The scan stops
    /// at the next photo and keeps what it had.
    func pauseBackgroundWork() {
        scanTask?.cancel()
    }

    /// Looks for squeezed photos, when that is switched on. Left to itself it
    /// waits until nothing is open; asked for by hand it runs regardless.
    func scanRecent(askedFor: Bool = false) async {
        guard findsSqueezed, RecentScanner.hasAccess, !isScanning, askedFor || !hasContent else { return }
        isScanning = true
        notice = Notice(text: "Checking recent photos…", isError: false, isBusy: true)
        defer {
            isScanning = false
            if notice?.isBusy == true { notice = nil }
        }
        let done = dealtWith, passedOver = foundOrdinary, learned = corrections
        let task = Task.detached(priority: .utility) {
            await RecentScanner.scan(dealtWith: done, passedOver: passedOver, corrections: learned)
        }
        scanTask = task
        let result = await task.value
        scanTask = nil
        rememberOrdinary(result.ordinary)
        found = result.found
        lastTally = result.tally
    }

    /// Puts the photos the scan found into the batch, each with the factor
    /// the scan read for it.
    func queueFound() {
        let photos = found
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
                      let thumbnail = await Thumbnailer.thumbnail(of: data, longestEdge: 600),
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
            for (index, item) in picked.enumerated() {
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
                          let thumbnail = await Thumbnailer.thumbnail(of: data, longestEdge: 600),
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
    /// else it is a custom factor. With a batch open it goes to the selected
    /// photos, each of which may have had a different one before.
    func use(factor: Double) async {
        guard abs(factor - session.squeeze.factor) > 0.001 else { return }
        let before = session.squeeze
        await setSessionFactor(factor)
        if mode == .batch { batch.apply(session.squeeze, replacing: before) }
    }

    private func setSessionFactor(_ factor: Double) async {
        let onStop = SqueezePreset.selectable.first { preset in
            preset.factor.map { abs($0 - factor) < 0.005 } ?? false
        }
        if let onStop {
            await session.choose(onStop)
        } else {
            await session.type(String(format: "%.2f", factor))
        }
    }

    // MARK: - Selection in a batch

    /// The factor every selected photo shares, or `nil` when they differ or
    /// none is selected.
    var selectionFactor: Double? {
        let chosen = batch.items.filter(\.isSelected)
            .map { ($0.squeeze ?? session.squeeze).factor }
        guard let first = chosen.first, chosen.allSatisfy({ abs($0 - first) < 0.005 }) else { return nil }
        return first
    }

    func toggleSelected(_ id: Batch.Item.ID) {
        guard let item = batch.items.first(where: { $0.id == id }) else { return }
        batch.setSelected(!item.isSelected, for: id)
        Task { await showSelectionFactor() }
    }

    func selectAll(_ selected: Bool) {
        batch.selectAll(selected)
        Task { await showSelectionFactor() }
    }

    /// Brings the slider to what the selection shares, without changing any photo.
    private func showSelectionFactor() async {
        guard let shared = selectionFactor, abs(shared - session.squeeze.factor) > 0.001 else { return }
        await setSessionFactor(shared)
    }

    /// Runs one output action at a time, and says so while it does.
    func perform(_ action: @MainActor () async -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        // A save under way when the app leaves the front is allowed to finish
        // rather than being frozen half-way through writing to the library.
        let assertion = BackgroundAssertion("StillScope output")
        defer {
            assertion.end()
            isWorking = false
        }
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
            let learned = learn(from: openLibraryID, factor: session.squeeze.factor)
            notice = Notice(text: "Saved to your library.", isError: false)
            if !learned && findsSqueezed {
                notice = Notice(text: "Saved, but not linked to your library, so its session cannot be matched.", isError: true)
            }
            if learned {
                // Others from the same session can be recognised now.
                await scanRecent(askedFor: true)
                if !found.isEmpty {
                    notice = Notice(text: "Saved. Found \(found.count) more from the same session. Clear to review.", isError: false)
                }
            }
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
        let failed = batch.items.count(where: { if case .failed = $0.state { true } else { false } })
        notice = failed == 0
            ? Notice(text: "\(batch.finishedCount) saved to your library.", isError: false)
            : Notice(text: "\(failed) could not be saved. Run again to retry them.", isError: true)
    }
}

/// Asks the system for time to finish a piece of work after the app leaves
/// the front, and gives it back when the work is done or time runs out.
@MainActor
final class BackgroundAssertion {
    private var id = UIBackgroundTaskIdentifier.invalid

    init(_ name: String) {
        id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in self?.end() }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

#if DEBUG
/// Store screenshots. Debug builds only: `-shot-dir <folder of images>` and
/// `-shot <empty|photo|factor|inspect|batch>` put the app in the state a
/// screenshot needs, through the same paths a person would take.
extension AppModel {
    fileprivate func stageShot() async {
        let defaults = UserDefaults.standard
        guard let shot = defaults.string(forKey: "shot"), shot != "empty",
              let folder = defaults.string(forKey: "shot-dir"),
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder)
        else { return }
        let files = names.sorted()
            .map { URL(fileURLWithPath: folder).appendingPathComponent($0) }
            .filter { ["jpg", "jpeg", "png", "heic", "tif", "tiff"].contains($0.pathExtension.lowercased()) }
        guard let first = files.first else { return }

        switch shot {
        case "photo", "factor", "inspect":
            await open(first)
            await setSessionFactor(1.5)
            isFactorPanelOpen = shot == "factor"
            isInspecting = shot == "inspect"
        case "batch":
            await setSessionFactor(1.5)
            for (index, file) in files.prefix(6).enumerated() {
                let id = batch.add(name: file.lastPathComponent) { try Data(contentsOf: file) }
                // The first four selected at the batch's factor; the rest left out, on their own.
                if index >= 4 {
                    batch.setSelected(false, for: id)
                    batch.setSqueeze(Squeeze(factor: 1.33), for: id)
                }
                if let data = try? Data(contentsOf: file) {
                    thumbnails[id] = await Thumbnailer.thumbnail(of: data, longestEdge: 600)
                }
            }
        default:
            break
        }
    }
}
#endif
