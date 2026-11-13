import Foundation
import DesqueezeCore

/// What the fake hands back as a "frame": a record of what was asked for.
struct Rendered: Equatable, Sendable {
    var factor: Double
    var longestEdge: Int
}

struct Unreadable: Error, LocalizedError {
    var errorDescription: String? { "That file could not be read as an image." }
}

/// Lets a test hold a render open and decide when, and in what order, it lands.
actor Gate {
    private var held: [Double: CheckedContinuation<Void, Never>] = [:]
    private var watchers: [Double: CheckedContinuation<Void, Never>] = [:]
    private var arrived: Set<Double> = []
    /// Every factor a render was asked for, in order.
    private(set) var asked: [Double] = []

    func hold(_ factor: Double) async {
        arrived.insert(factor)
        asked.append(factor)
        watchers.removeValue(forKey: factor)?.resume()
        await withCheckedContinuation { held[factor] = $0 }
    }
    func untilAsked(for factor: Double) async {
        if arrived.contains(factor) { return }
        await withCheckedContinuation { watchers[factor] = $0 }
    }
    func release(_ factor: Double) { held.removeValue(forKey: factor)?.resume() }
}

/// Stands in for Core Image at the one boundary the session does not own.
final class FakeRenderer: FrameRenderer, @unchecked Sendable {
    static let unreadable = Data("not an image".utf8)
    var gate: Gate?
    /// Holds `size(of:)` open, keyed 0, to test what happens mid-open.
    var openGate: Gate?
    var exported = Fixture.jpeg(Fixture.jfif)

    func size(of source: Data) async throws -> PixelSize {
        await openGate?.hold(0)
        if source == Self.unreadable { throw Unreadable() }
        return PixelSize(width: 6000, height: 4000)
    }
    func preview(of source: Data, squeeze: Squeeze, longestEdge: Int) async throws -> Rendered {
        await gate?.hold(squeeze.factor)
        return Rendered(factor: squeeze.factor, longestEdge: longestEdge)
    }
    func export(_ source: Data, squeeze: Squeeze) async throws -> Data { exported }
}
