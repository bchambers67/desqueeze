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

    @Test("a photo stored on its side is marked upright on the export, whose pixels already are")
    func uprights() {
        let source = Fixture.jpeg(Fixture.app1(width: 6000, height: 4000, orientation: 6))
        let result = CaptureMetadata.carry(from: source, onto: Fixture.jpeg(), size: PixelSize(width: 8000, height: 6000))
        #expect(result == Fixture.jpeg(Fixture.app1(width: 8000, height: 6000, orientation: 1)))
    }

    @Test("XMP shares Exif’s marker; it is neither mistaken for the capture data nor thrown away")
    func skipsXMP() {
        let source = Fixture.jpeg(Fixture.xmp, Fixture.app1(width: 6000, height: 4000))
        let export = Fixture.jpeg(Fixture.xmp, Fixture.jfif)
        let result = CaptureMetadata.carry(from: source, onto: export, size: PixelSize(width: 9000, height: 4000))
        #expect(result == Fixture.jpeg(Fixture.app1(width: 9000, height: 4000), Fixture.xmp, Fixture.jfif))
    }

    @Test("a block written out byte by byte from the Exif layout changes in its width field and nowhere else")
    func literal() {
        let source: [UInt8] = [
            0xff, 0xd8,                                                 // SOI
            0xff, 0xe1, 0x00, 0x22,                                     // APP1, length 34
            0x45, 0x78, 0x69, 0x66, 0x00, 0x00,                         // "Exif\\0\\0"
            0x49, 0x49, 0x2a, 0x00, 0x08, 0x00, 0x00, 0x00,             // II, 42, IFD0 at 8
            0x01, 0x00,                                                 // one entry
            0x02, 0xa0, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 0x70, 0x17, 0x00, 0x00,   // A002 LONG = 6000
            0x00, 0x00, 0x00, 0x00,                                     // no next IFD
            0xff, 0xda, 0x00, 0x02, 0x11, 0x22, 0x33, 0xff, 0xd9,
        ]
        var expected = source
        expected[30] = 0xe0; expected[31] = 0x2e                        // 12000 = 0x2EE0, little-endian
        let export = Data([0xff, 0xd8, 0xff, 0xda, 0x00, 0x02, 0x11, 0x22, 0x33, 0xff, 0xd9])
        #expect(CaptureMetadata.carry(from: Data(source), onto: export, size: PixelSize(width: 12000, height: 4000)) == Data(expected))
    }
}
