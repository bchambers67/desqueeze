import Foundation
import Testing
import DesqueezeCore

@Suite("Editor session") @MainActor
struct EditorSessionTests {
    let photo = Fixture.jpeg(Fixture.app1(width: 6000, height: 4000))

    @Test("opening a photo shows it corrected at 2×, with both sizes known")
    func opens() async {
        let session = EditorSession(renderer: FakeRenderer())
        await session.open(photo)
        #expect(session.preview?.factor == 2.0)
        #expect(session.sourceSize == PixelSize(width: 6000, height: 4000))
        #expect(session.outputSize == PixelSize(width: 12000, height: 4000))
    }

    @Test("choosing other glass re-renders at that factor")
    func chooses() async {
        let session = EditorSession(renderer: FakeRenderer())
        await session.open(photo)
        await session.choose(.x133)
        #expect(session.preview?.factor == 1.33)
        #expect(session.outputSize == PixelSize(width: 7980, height: 4000))
        #expect(session.preset == .x133)
    }

    @Test("when renders finish out of order, the last factor chosen is the one shown")
    func latestWins() async {
        let renderer = FakeRenderer()
        let session = EditorSession(renderer: renderer)
        await session.open(photo)

        let gate = Gate()
        renderer.gate = gate
        let first = Task { await session.choose(.x133) }
        await gate.untilAsked(for: 1.33)
        let second = Task { await session.choose(.x180) }
        await gate.untilAsked(for: 1.80)

        await gate.release(1.80)
        await second.value
        await gate.release(1.33)   // the stale render lands last
        await first.value

        #expect(session.preview?.factor == 1.80)
    }

    @Test("a file that is not an image says so, and a good one afterwards clears it")
    func unreadable() async {
        let session = EditorSession(renderer: FakeRenderer())
        await session.open(FakeRenderer.unreadable)
        #expect(session.failure == "That file could not be read as an image.")
        #expect(session.preview == nil)
        #expect(session.hasPhoto == false)

        await session.open(photo)
        #expect(session.failure == nil)
        #expect(session.preview != nil)
        #expect(session.hasPhoto)
    }

    @Test("the export is the full-size JPEG with the photo’s capture data carried onto it")
    func exports() async throws {
        let session = EditorSession(renderer: FakeRenderer())
        await session.open(photo)
        await session.choose(.x150)
        let file = try await session.export()
        #expect(file == Fixture.jpeg(Fixture.app1(width: 9000, height: 4000), Fixture.jfif))
    }

    @Test("there is nothing to export before a photo is open")
    func exportsNothing() async {
        let session = EditorSession(renderer: FakeRenderer())
        await #expect(throws: EditorSession<FakeRenderer>.NothingOpen.self) { try await session.export() }
    }

    @Test("unfolding to a larger display re-renders for it and keeps the photo and factor")
    func refits() async {
        let session = EditorSession(renderer: FakeRenderer())
        await session.open(photo)
        await session.choose(.x165)

        await session.fit(longestEdge: 3300)

        #expect(session.preview == Rendered(factor: 1.65, longestEdge: 3300))
        #expect(session.preset == .x165)
        #expect(session.hasPhoto)
    }

    @Test("a typed factor is used as a custom squeeze")
    func typed() async {
        let session = EditorSession(renderer: FakeRenderer())
        await session.open(photo)
        await session.type("1,4")
        #expect(session.preset == .custom)
        #expect(session.preview?.factor == 1.4)
        #expect(session.typedFactorIsValid)
    }

    @Test("typing something that is not a number flags it and leaves the last good frame up")
    func typedNonsense() async {
        let session = EditorSession(renderer: FakeRenderer())
        await session.open(photo)
        await session.choose(.x133)
        await session.type("wide")
        #expect(session.typedFactorIsValid == false)
        #expect(session.preview?.factor == 1.33)
        #expect(session.squeeze.factor == 1.33)
    }

    @Test("the session reports that it is working while a render is in flight")
    func busy() async {
        let renderer = FakeRenderer()
        let session = EditorSession(renderer: renderer)
        await session.open(photo)
        #expect(session.isRendering == false)

        let gate = Gate()
        renderer.gate = gate
        let render = Task { await session.choose(.x125) }
        await gate.untilAsked(for: 1.25)
        #expect(session.isRendering)

        await gate.release(1.25)
        await render.value
        #expect(session.isRendering == false)
    }

    @Test("inspection gets every pixel when the frame is small enough to hold, and a capped frame when it is not")
    func inspects() async throws {
        let session = EditorSession(renderer: FakeRenderer())
        await session.open(photo)

        await session.choose(.x133)          // 7980 wide: fits
        #expect(try await session.inspectionFrame() == Rendered(factor: 1.33, longestEdge: 7980))

        await session.choose(.x200)          // 12000 wide: too large to hold as one bitmap
        #expect(try await session.inspectionFrame() == Rendered(factor: 2.0, longestEdge: 8192))
    }
}
