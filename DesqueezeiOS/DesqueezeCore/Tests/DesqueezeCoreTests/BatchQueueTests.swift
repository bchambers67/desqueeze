import Foundation
import Testing
import DesqueezeCore

/// Where finished files go. The photo library in the app; a list here.
@MainActor final class Shelf {
    var saved: [(name: String, file: Data)] = []
    var refuse: Set<String> = []
    struct Full: Error, LocalizedError { var errorDescription: String? { "The library refused the file." } }
    func save(name: String, file: Data) async throws {
        if refuse.contains(name) { throw Full() }
        saved.append((name, file))
    }
}

@Suite("Batch queue") @MainActor
struct BatchQueueTests {
    let photo = Fixture.jpeg(Fixture.app1(width: 6000, height: 4000))
    func queue() -> BatchQueue<FakeRenderer> { BatchQueue(renderer: FakeRenderer()) }

    @Test("every queued photo is saved, named for the factor it was corrected at")
    func runs() async {
        let queue = queue(), shelf = Shelf()
        queue.add(name: "IMG_0001.HEIC") { self.photo }
        queue.add(name: "IMG_0002.jpg") { self.photo }

        await queue.run(squeeze: Squeeze(factor: 1.5), saving: shelf.save)

        #expect(shelf.saved.map(\.name) == ["IMG_0001_desqueeze_1_50x.jpg", "IMG_0002_desqueeze_1_50x.jpg"])
        #expect(queue.items.map(\.state) == [.done, .done])
    }

    @Test("a photo given its own factor uses it; the rest follow the batch")
    func overrides() async {
        let queue = queue(), shelf = Shelf()
        queue.add(name: "a.jpg") { self.photo }
        queue.add(name: "b.jpg") { self.photo }
        queue.setSqueeze(Squeeze(factor: 1.33), for: queue.items[1].id)

        await queue.run(squeeze: Squeeze(factor: 2.0), saving: shelf.save)

        #expect(shelf.saved.map(\.name) == ["a_desqueeze_2_00x.jpg", "b_desqueeze_1_33x.jpg"])
    }

    @Test("one photo failing is recorded against it and does not stop the others")
    func isolatesFailure() async {
        let queue = queue(), shelf = Shelf()
        queue.add(name: "good.jpg") { self.photo }
        queue.add(name: "gone.jpg") { throw Unreadable() }
        queue.add(name: "also-good.jpg") { self.photo }

        await queue.run(squeeze: Squeeze(factor: 2.0), saving: shelf.save)

        #expect(queue.items.map(\.state) == [.done, .failed("That file could not be read as an image."), .done])
        #expect(shelf.saved.map(\.name) == ["good_desqueeze_2_00x.jpg", "also-good_desqueeze_2_00x.jpg"])
    }

    @Test("batch exports keep each photo’s capture data, sized for its own factor")
    func carriesMetadata() async {
        let queue = queue(), shelf = Shelf()
        queue.add(name: "a.jpg") { self.photo }
        await queue.run(squeeze: Squeeze(factor: 1.5), saving: shelf.save)
        #expect(shelf.saved.first?.file == Fixture.jpeg(Fixture.app1(width: 9000, height: 4000), Fixture.jfif))
    }

    @Test("a batch run with a matte borders every photo and records the larger size")
    func mattes() async {
        let renderer = FakeRenderer()
        let queue = BatchQueue(renderer: renderer), shelf = Shelf()
        queue.add(name: "a.jpg") { self.photo }
        await queue.run(squeeze: Squeeze(factor: 1.5), matte: Matte(fraction: 0.05), saving: shelf.save)
        #expect(renderer.mattes == [Matte(fraction: 0.05)])
        #expect(shelf.saved.first?.file == Fixture.jpeg(Fixture.app1(width: 9900, height: 4900), Fixture.jfif))
    }

    @Test("running again retries what failed and does not save finished photos twice")
    func retries() async {
        let queue = queue(), shelf = Shelf()
        queue.add(name: "a.jpg") { self.photo }
        queue.add(name: "b.jpg") { self.photo }
        shelf.refuse = ["b_desqueeze_2_00x.jpg"]
        await queue.run(squeeze: Squeeze(factor: 2.0), saving: shelf.save)
        #expect(queue.items.map(\.state) == [.done, .failed("The library refused the file.")])

        shelf.refuse = []
        await queue.run(squeeze: Squeeze(factor: 2.0), saving: shelf.save)

        #expect(queue.items.map(\.state) == [.done, .done])
        #expect(shelf.saved.map(\.name) == ["a_desqueeze_2_00x.jpg", "b_desqueeze_2_00x.jpg"])
    }

    @Test("asking to run while a run is under way does not save anything twice")
    func runsOnce() async {
        let queue = queue(), shelf = Shelf(), gate = Gate()
        queue.add(name: "a.jpg") { await gate.hold(1); return self.photo }

        let first = Task { await queue.run(squeeze: Squeeze(factor: 2.0), saving: shelf.save) }
        await gate.untilAsked(for: 1)
        await queue.run(squeeze: Squeeze(factor: 2.0), saving: shelf.save)   // the second tap
        await gate.release(1)
        await first.value

        #expect(shelf.saved.map(\.name) == ["a_desqueeze_2_00x.jpg"])
    }

    @Test("a photo removed while the batch runs is skipped, and the rest still save")
    func survivesRemoval() async {
        let queue = queue(), shelf = Shelf(), gate = Gate()
        queue.add(name: "a.jpg") { await gate.hold(1); return self.photo }
        queue.add(name: "b.jpg") { self.photo }
        queue.add(name: "c.jpg") { self.photo }

        let running = Task { await queue.run(squeeze: Squeeze(factor: 2.0), saving: shelf.save) }
        await gate.untilAsked(for: 1)
        queue.remove(queue.items[1].id)
        await gate.release(1)
        await running.value

        #expect(shelf.saved.map(\.name) == ["a_desqueeze_2_00x.jpg", "c_desqueeze_2_00x.jpg"])
        #expect(queue.items.map(\.state) == [.done, .done])
    }
}
