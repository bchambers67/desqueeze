import Testing
import DesqueezeCore

@Suite("Squeeze detector")
struct SqueezeDetectorTests {
    /// A plain 3:2 camera frame with nothing known about it.
    func facts(name: String? = "IMG_0001.JPG", width: Int = 6000, height: Int = 4000,
               lens: String? = nil, face: Double? = nil, text: Double? = nil, body: Double? = nil,
               detail: Double? = nil, session: Double? = nil,
               screenshot: Bool = false, edited: Bool = false) -> PhotoFacts {
        PhotoFacts(name: name, size: PixelSize(width: width, height: height), lensModel: lens,
                   faceFactor: face, textFactor: text, bodyFactor: body, detailFactor: detail,
                   sessionFactor: session, isScreenshot: screenshot, isEdited: edited)
    }

    @Test("an ordinary photo is left alone")
    func ordinary() {
        #expect(SqueezeDetector.verdict(for: facts()) == nil)
        #expect(SqueezeDetector.verdict(for: facts(lens: "iPhone 17 Pro back triple camera 6.86mm f/1.78")) == nil)
    }

    @Test("a lens that names itself anamorphic is flagged, with the factor it states",
          arguments: [("SIRUI 50mm T2.9 1.6x Anamorphic", 1.6), ("Blazar Remus 45mm 1.5X Anamorphic", 1.5),
                      ("Great Joy 60mm T2.9 1.33x anamorphic", 1.33), ("Laowa Nanomorph 35mm T2.4 1.5X", 1.5),
                      ("Atlas Orion 40mm 2x Anamorphic", 2.0)])
    func namedLens(lens: String, factor: Double) {
        #expect(SqueezeDetector.verdict(for: facts(lens: lens)) == .init(factor: factor, reason: .lens))
    }

    @Test("an anamorphic lens that gives no factor is flagged, and the factor left to the batch")
    func lensWithoutFactor() {
        #expect(SqueezeDetector.verdict(for: facts(lens: "Vintage Anamorphic Adapter")) == .init(factor: nil, reason: .lens))
    }

    @Test("a focal length is not mistaken for a squeeze factor")
    func focalLengthIsNotAFactor() {
        #expect(SqueezeDetector.verdict(for: facts(lens: "Anamorphic 50mm T2")) == .init(factor: nil, reason: .lens))
    }

    @Test("narrow faces flag a photo, snapped to the nearest lens factor")
    func faces() {
        #expect(SqueezeDetector.verdict(for: facts(face: 1.36)) == .init(factor: 1.33, reason: .faces))
        #expect(SqueezeDetector.verdict(for: facts(face: 1.92)) == .init(factor: 1.92, reason: .faces))
    }

    @Test("faces only slightly narrow are not enough")
    func slightFaces() {
        #expect(SqueezeDetector.verdict(for: facts(face: 1.15)) == nil)
    }

    @Test("when the lens states a factor, it wins over the faces")
    func lensBeatsFaces() {
        #expect(SqueezeDetector.verdict(for: facts(lens: "SIRUI 1.33x Anamorphic", face: 1.6)) == .init(factor: 1.33, reason: .lens))
    }

    @Test("when the lens gives no factor, the faces supply it")
    func facesFillIn() {
        #expect(SqueezeDetector.verdict(for: facts(lens: "Anamorphic adapter", face: 1.52)) == .init(factor: 1.5, reason: .lens))
    }

    @Test("photos that are already corrected are left alone")
    func alreadyDone() {
        let lens = "SIRUI 50mm 1.6x Anamorphic"
        #expect(SqueezeDetector.verdict(for: facts(name: "IMG_0001_desqueeze_1_60x.jpg", lens: lens)) == nil)
        #expect(SqueezeDetector.verdict(for: facts(name: "desqueeze_1.60x.jpg", lens: lens)) == nil)
        #expect(SqueezeDetector.verdict(for: facts(lens: lens, edited: true)) == nil)
        // Already as wide as a corrected frame.
        #expect(SqueezeDetector.verdict(for: facts(width: 9600, height: 4000, lens: lens)) == nil)
    }

    @Test("screenshots are never flagged")
    func screenshots() {
        #expect(SqueezeDetector.verdict(for: facts(face: 1.6, screenshot: true)) == nil)
    }

    @Test("text and bodies are not trusted alone")
    func looseReadingsNeedCompany() {
        #expect(SqueezeDetector.verdict(for: facts(text: 1.5)) == nil)
        #expect(SqueezeDetector.verdict(for: facts(body: 1.5)) == nil)
        #expect(SqueezeDetector.verdict(for: facts(detail: 1.5)) == nil)
    }

    @Test("two readings from the picture that agree flag the photo, at the factor between them")
    func agreement() {
        #expect(SqueezeDetector.verdict(for: facts(text: 1.48, body: 1.56)) == .init(factor: 1.5, reason: .picture))
        #expect(SqueezeDetector.verdict(for: facts(text: 1.3, detail: 1.36)) == .init(factor: 1.33, reason: .picture))
    }

    @Test("readings that disagree about the factor do not flag the photo")
    func disagreement() {
        #expect(SqueezeDetector.verdict(for: facts(text: 1.3, body: 1.9)) == nil)
    }

    @Test("detail can back another reading up, but two detail-only signs are not enough")
    func detailOnlySupports() {
        #expect(SqueezeDetector.verdict(for: facts(body: 1.6, detail: 1.55)) == .init(factor: 1.6, reason: .picture))
        #expect(SqueezeDetector.verdict(for: facts(detail: 1.6)) == nil)
    }

    @Test("a reading that says the photo is ordinary counts against")
    func ordinaryCountsAgainst() {
        // Faces say squeezed, text says ordinary: one each, so it is left alone.
        #expect(SqueezeDetector.verdict(for: facts(face: 1.4, text: 1.0)) == nil)
        // Two say squeezed and one ordinary: flagged.
        #expect(SqueezeDetector.verdict(for: facts(face: 1.5, text: 1.0, body: 1.52)) == .init(factor: 1.5, reason: .picture))
    }

    @Test("a photo from the same session as a corrected one is flagged at that factor")
    func session() {
        #expect(SqueezeDetector.verdict(for: facts(session: 1.6)) == .init(factor: 1.6, reason: .session))
        // Even when its own readings say nothing or little.
        #expect(SqueezeDetector.verdict(for: facts(text: 1.0, session: 1.33)) == .init(factor: 1.33, reason: .session))
    }
}
