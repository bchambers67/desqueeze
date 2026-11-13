import Foundation

/// Hand-built JPEG byte streams. Written out longhand, independently of the
/// code under test, so an expected value is never computed the way the
/// implementation computes it.
enum Fixture {
    enum Order { case little, big }
    enum Layout { case subIFD, ifd0 }
    enum Width { case long, short }

    private static func u16(_ v: Int, _ o: Order) -> [UInt8] {
        o == .little ? [UInt8(v & 0xff), UInt8(v >> 8 & 0xff)] : [UInt8(v >> 8 & 0xff), UInt8(v & 0xff)]
    }
    private static func u32(_ v: Int, _ o: Order) -> [UInt8] {
        let b = [UInt8(v & 0xff), UInt8(v >> 8 & 0xff), UInt8(v >> 16 & 0xff), UInt8(v >> 24 & 0xff)]
        return o == .little ? b : b.reversed()
    }
    private static func entry(_ tag: Int, _ w: Width, _ value: Int, _ o: Order) -> [UInt8] {
        let type = w == .long ? 4 : 3
        let field = w == .long ? u32(value, o) : u16(value, o) + [0, 0]
        return u16(tag, o) + u16(type, o) + u32(1, o) + field
    }

    /// An Exif APP1 segment recording `width`×`height`, plus a Make tag so
    /// there is something besides the dimensions that must survive untouched.
    static func app1(width: Int, height: Int, order: Order = .little,
                     layout: Layout = .subIFD, value: Width = .long) -> [UInt8] {
        var tiff: [UInt8] = (order == .little ? [0x49, 0x49] : [0x4d, 0x4d]) + u16(0x2a, order) + u32(8, order)
        let make = entry(0x010f, .short, 0x4343, order)   // stand-in "Make"
        let dims = entry(0xa002, value, width, order) + entry(0xa003, value, height, order)
        switch layout {
        case .ifd0:
            tiff += u16(3, order) + make + dims + u32(0, order)
        case .subIFD:
            // IFD0 at 8: count(2) + 2 entries(24) + next(4) = 30 → sub-IFD at 38.
            tiff += u16(2, order) + make + entry(0x8769, .long, 38, order) + u32(0, order)
            tiff += u16(2, order) + dims + u32(0, order)
        }
        let body: [UInt8] = [0x45, 0x78, 0x69, 0x66, 0, 0] + tiff
        return [0xff, 0xe1] + u16(body.count + 2, .big) + body
    }

    static let soi: [UInt8] = [0xff, 0xd8]
    static let jfif: [UInt8] = [0xff, 0xe0, 0x00, 0x04, 0x4a, 0x46]
    /// Start-of-scan onward: stands in for the compressed picture.
    static let scan: [UInt8] = [0xff, 0xda, 0x00, 0x02, 0x11, 0x22, 0x33, 0xff, 0xd9]

    static func jpeg(_ segments: [UInt8]...) -> Data { Data(soi + segments.flatMap { $0 } + scan) }
}
