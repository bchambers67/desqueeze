import Foundation
import Observation

/// Many photographs corrected in one go.
///
/// Photos are held as a way to load them, not as bytes: a queue of 48MP frames
/// kept in memory at once would not fit, so each is loaded when its turn comes
/// and released when it is saved.
@MainActor @Observable
public final class BatchQueue<Renderer: FrameRenderer> {

    public struct Item: Identifiable, Sendable {
        public enum State: Equatable, Sendable {
            case waiting, working, done
            case failed(String)
        }
        public let id: UUID
        public let name: String
        public internal(set) var state: State = .waiting
        /// This photo's own factor, when it differs from the batch.
        public internal(set) var squeeze: Squeeze?
        let load: @Sendable () async throws -> Data
    }

    public private(set) var items: [Item] = []

    private let renderer: Renderer
    public init(renderer: Renderer) { self.renderer = renderer }

    public func add(name: String, load: @escaping @Sendable () async throws -> Data) {
        items.append(Item(id: UUID(), name: name, load: load))
    }

    public func remove(_ id: Item.ID) { items.removeAll { $0.id == id } }
    public func clear() { items.removeAll() }

    public var finishedCount: Int { items.count(where: { $0.state == .done }) }
    public private(set) var isRunning = false

    /// Gives one photo its own factor; `nil` returns it to following the batch.
    public func setSqueeze(_ squeeze: Squeeze?, for id: Item.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].squeeze = squeeze
    }

    /// Corrects each unfinished photo and hands the result to `save`. A call
    /// made while a run is under way returns at once.
    public func run(squeeze: Squeeze, saving save: (_ name: String, _ file: Data) async throws -> Void) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        // Walked by identity, not position: the list can change under a run,
        // and an index taken before an await may not mean the same photo after.
        for id in items.filter({ $0.state != .done }).map(\.id) {
            guard let item = items.first(where: { $0.id == id }) else { continue }
            setState(.working, for: id)
            do {
                let source = try await item.load()
                let own = item.squeeze ?? squeeze
                let size = own.outputSize(for: try await renderer.size(of: source))
                let jpeg = try await renderer.export(source, squeeze: own)
                let file = CaptureMetadata.carry(from: source, onto: jpeg, size: size)
                try await save(Self.outputName(for: item.name, squeeze: own), file)
                setState(.done, for: id)
            } catch {
                setState(.failed(error.localizedDescription), for: id)
            }
        }
    }

    private func setState(_ state: Item.State, for id: Item.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = state
    }

    /// `IMG_0001.HEIC` at 1.5× → `IMG_0001_desqueeze_1_50x.jpg`. The factor goes
    /// in the name without a dot, so it cannot be mistaken for an extension.
    static func outputName(for name: String, squeeze: Squeeze) -> String {
        let base = name.split(separator: ".").dropLast().joined(separator: ".")
        let tag = String(format: "%.2f", squeeze.factor).replacingOccurrences(of: ".", with: "_")
        return "\(base.isEmpty ? name : base)_desqueeze_\(tag)x.jpg"
    }
}
