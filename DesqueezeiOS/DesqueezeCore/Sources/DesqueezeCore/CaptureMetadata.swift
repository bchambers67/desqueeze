import Foundation

/// Carries a photograph's capture metadata across a re-encode.
///
/// Rendering through Core Image produces a clean JPEG: date, camera, lens and
/// location are gone. This lifts the Exif block from the source file and sets
/// it on the export, with the recorded pixel dimensions corrected to the new
/// size so the file does not describe an image that no longer exists.
///
/// Only inline 4-byte value fields are ever overwritten, never a length or an
/// offset, so nothing in the block moves. Anything not fully recognised is
/// carried exactly as found: stale dimensions are a blemish, corrupt metadata
/// is damage.
public enum CaptureMetadata {

    /// `export` with `source`'s Exif block in place of its own. Returns
    /// `export` unchanged when either is not a JPEG or `source` has no Exif.
    public static func carry(from source: Data, onto export: Data, size: PixelSize) -> Data {
        let src = [UInt8](source), out = [UInt8](export)
        guard isJPEG(out), let block = exifSegment(in: src) else { return export }
        let patched = withDimensions(size, in: Array(src[block]))
        // The encoder may have written a minimal Exif block of its own. Two
        // would leave readers to pick one; the source's is the one that matters.
        var rest = Array(out[2...])
        if let own = exifSegment(in: out) { rest.removeSubrange((own.lowerBound - 2)..<(own.upperBound - 2)) }
        return Data(Array(out[0..<2]) + patched + rest)
    }

    // MARK: - JPEG structure

    private static func isJPEG(_ b: [UInt8]) -> Bool { b.count >= 4 && b[0] == 0xff && b[1] == 0xd8 }

    /// The byte range of the first APP1 segment before the scan data.
    private static func exifSegment(in b: [UInt8]) -> Range<Int>? {
        guard isJPEG(b) else { return nil }
        var i = 2
        while i + 4 <= b.count {
            guard b[i] == 0xff else { return nil }          // desynchronised
            let marker = b[i + 1]
            if marker == 0xda { return nil }                // scan starts: no Exif
            let length = Int(b[i + 2]) << 8 | Int(b[i + 3])
            guard length >= 2, i + 2 + length <= b.count else { return nil }
            // APP1 carries XMP as well as Exif; only the Exif one is wanted.
            if marker == 0xe1, length >= 8, Array(b[(i + 4)..<(i + 10)]) == exifHeader {
                return i..<(i + 2 + length)
            }
            i += 2 + length
        }
        return nil
    }

    // MARK: - TIFF

    private static let exifHeader: [UInt8] = [0x45, 0x78, 0x69, 0x66, 0, 0]
    private static let tiffStart = 4 + 6   // FFE1, length, "Exif\0\0"

    private static func withDimensions(_ size: PixelSize, in segment: [UInt8]) -> [UInt8] {
        var b = segment
        guard b.count >= 20, Array(b[4..<10]) == exifHeader else { return segment }

        let little: Bool
        switch (b[tiffStart], b[tiffStart + 1]) {
        case (0x49, 0x49): little = true
        case (0x4d, 0x4d): little = false
        default: return segment
        }
        func u16(_ at: Int) -> Int {
            little ? Int(b[at]) | Int(b[at + 1]) << 8 : Int(b[at]) << 8 | Int(b[at + 1])
        }
        func u32(_ at: Int) -> Int {
            little ? u16(at) | u16(at + 2) << 16 : u16(at) << 16 | u16(at + 2)
        }
        guard u16(tiffStart + 2) == 0x2a else { return segment }

        var patched = 0
        var subIFD: Int?
        /// Walks one IFD. `false` when it runs off the block.
        func walk(_ ifd: Int, followPointer: Bool) -> Bool {
            guard ifd + 2 <= b.count else { return false }
            for j in 0..<u16(ifd) {
                let entry = ifd + 2 + j * 12
                guard entry + 12 <= b.count else { return false }
                let tag = u16(entry)
                if followPointer, tag == 0x8769 { subIFD = tiffStart + u32(entry + 8); continue }
                // The renderer bakes rotation into the pixels. Left as found,
                // the tag would have every viewer rotate the export again.
                let isOrientation = followPointer && tag == 0x0112
                guard tag == 0xa002 || tag == 0xa003 || isOrientation else { continue }
                let value = isOrientation ? 1 : tag == 0xa002 ? size.width : size.height
                let bytes: [UInt8]
                switch u16(entry + 2) {
                case 3: bytes = [UInt8(value & 0xff), UInt8(value >> 8 & 0xff)]
                case 4: bytes = [UInt8(value & 0xff), UInt8(value >> 8 & 0xff),
                                 UInt8(value >> 16 & 0xff), UInt8(value >> 24 & 0xff)]
                default: continue   // an unexpected type is left as found
                }
                let ordered = little ? bytes : bytes.reversed()
                b.replaceSubrange((entry + 8)..<(entry + 8 + ordered.count), with: ordered)
                patched += 1
            }
            return true
        }

        // Cameras put the dimensions in the Exif sub-IFD; some writing
        // libraries put them straight in IFD0. Both occur.
        guard walk(tiffStart + u32(tiffStart + 4), followPointer: true) else { return segment }
        if let subIFD, !walk(subIFD, followPointer: false) { return segment }
        return patched > 0 ? b : segment
    }
}
