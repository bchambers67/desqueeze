import Foundation
import Testing
import DesqueezeCore

@Suite("Capture metadata")
struct CaptureMetadataTests {
    @Test("the source's capture data lands on the export, recording the new size")
    func carries() {
        let source = Fixture.jpeg(Fixture.app1(width: 6000, height: 4000))
        let export = Fixture.jpeg(Fixture.jfif)

        let result = CaptureMetadata.carry(from: source, onto: export, size: PixelSize(width: 12000, height: 4000))

        #expect(result == Fixture.jpeg(Fixture.app1(width: 12000, height: 4000), Fixture.jfif))
    }

    @Test("big-endian blocks with 16-bit dimensions held in IFD0 are corrected too")
    func otherLayout() {
        let source = Fixture.jpeg(Fixture.app1(width: 3000, height: 2000, order: .big, layout: .ifd0, value: .short))
        let result = CaptureMetadata.carry(from: source, onto: Fixture.jpeg(), size: PixelSize(width: 4500, height: 2000))
        #expect(result == Fixture.jpeg(Fixture.app1(width: 4500, height: 2000, order: .big, layout: .ifd0, value: .short)))
    }

    @Test("a source with no capture data leaves the export exactly as it was")
    func nothingToCarry() {
        let export = Fixture.jpeg(Fixture.jfif)
        #expect(CaptureMetadata.carry(from: Fixture.jpeg(), onto: export, size: PixelSize(width: 10, height: 10)) == export)
        #expect(CaptureMetadata.carry(from: Data([0x89, 0x50, 0x4e, 0x47]), onto: export, size: PixelSize(width: 10, height: 10)) == export)
    }

    @Test("a block that cannot be fully read is carried untouched rather than repaired")
    func damagedBlock() {
        var block = Fixture.app1(width: 6000, height: 4000)
        block[18] = 0xff   // IFD0 now claims far more entries than the block holds
        let result = CaptureMetadata.carry(from: Fixture.jpeg(block), onto: Fixture.jpeg(), size: PixelSize(width: 1, height: 1))
        #expect(result == Fixture.jpeg(block))
    }

    @Test("an export that already has its own Exif block gets the source one instead, not both")
    func replaces() {
        let source = Fixture.jpeg(Fixture.app1(width: 6000, height: 4000))
        let export = Fixture.jpeg(Fixture.jfif, Fixture.app1(width: 12000, height: 4000, order: .big, layout: .ifd0))
        let result = CaptureMetadata.carry(from: source, onto: export, size: PixelSize(width: 12000, height: 4000))
        #expect(result == Fixture.jpeg(Fixture.app1(width: 12000, height: 4000), Fixture.jfif))
    }
}
