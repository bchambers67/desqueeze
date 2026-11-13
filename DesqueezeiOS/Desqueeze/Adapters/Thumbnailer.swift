import Foundation
import ImageIO

/// Small, upright previews for the batch grid.
///
/// ImageIO decodes straight to the size asked for, so a 48MP frame costs a
/// thumbnail's worth of memory, not its own. These are made once, of the
/// photo as shot; the grid shapes them to the squeeze factor when drawing, so
/// a moving slider never asks for another.
enum Thumbnailer {
    static func thumbnail(of data: Data, longestEdge: Int) async -> CoreImageRenderer.Frame? {
        await Task.detached(priority: .userInitiated) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: longestEdge,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            else { return nil }
            return CoreImageRenderer.Frame(image: image)
        }.value
    }
}
