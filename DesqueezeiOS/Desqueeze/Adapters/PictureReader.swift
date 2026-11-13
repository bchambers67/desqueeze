import CoreGraphics
import DesqueezeCore
import Foundation
import ImageIO
import Vision

/// Takes the measurements `PictureSignals` works from: the text Vision can
/// read, the people it can find, and the grey levels of the frame.
///
/// Everything is measured on one small upright copy of the photo, as shot.
/// The copy must keep the photo's own proportions: these readings are of the
/// squeeze, so a copy that had been reshaped would have nothing to read.
enum PictureReader {

    struct Readings: Sendable {
        var text: Double?
        var body: Double?
        var detail: Double?
    }

    static func readings(for source: Data) async -> Readings {
        await Task.detached(priority: .utility) { measure(source) }.value
    }

    private static func measure(_ source: Data) -> Readings {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600,
        ]
        guard let imageSource = CGImageSourceCreateWithData(source as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        else { return Readings() }

        let width = Double(image.width), height = Double(image.height)

        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .fast
        text.usesLanguageCorrection = false
        let pose = VNDetectHumanBodyPoseRequest()
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([text, pose])

        let lines = (text.results ?? []).compactMap { line -> PictureSignals.TextLine? in
            guard let best = line.topCandidates(1).first, best.confidence >= 0.5 else { return nil }
            return PictureSignals.TextLine(characters: best.string.count,
                                           width: line.boundingBox.width * width,
                                           height: line.boundingBox.height * height)
        }

        let people = (pose.results ?? []).compactMap { person -> PictureSignals.Body? in
            guard let left = try? person.recognizedPoint(.leftShoulder),
                  let right = try? person.recognizedPoint(.rightShoulder),
                  let neck = try? person.recognizedPoint(.neck),
                  let hips = try? person.recognizedPoint(.root),
                  min(left.confidence, right.confidence, neck.confidence, hips.confidence) > 0.3
            else { return nil }
            let acrossX = (left.location.x - right.location.x) * width
            let acrossY = (left.location.y - right.location.y) * height
            let downX = (neck.location.x - hips.location.x) * width
            let downY = (neck.location.y - hips.location.y) * height
            // Standing or sitting upright only: a body leaning or lying down
            // mixes the squeezed direction into the wrong measurement.
            guard abs(acrossX) > abs(acrossY) * 2, abs(downY) > abs(downX) * 2 else { return nil }
            return PictureSignals.Body(shoulderWidth: hypot(acrossX, acrossY), torsoLength: hypot(downX, downY))
        }

        return Readings(text: PictureSignals.textFactor(lines: lines),
                        body: PictureSignals.bodyFactor(people: people),
                        detail: detail(in: image))
    }

    /// Fine detail is measured on grey levels at about 512 pixels across:
    /// small enough to be past the sensor's own sharpening, large enough to
    /// keep the scene's texture.
    private static func detail(in image: CGImage) -> Double? {
        let scale = 512.0 / Double(max(image.width, image.height))
        let width = max(Int(Double(image.width) * scale), 1)
        let height = max(Int(Double(image.height) * scale), 1)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let bytes = context.data else { return nil }
        let pixels = [UInt8](UnsafeBufferPointer(start: bytes.assumingMemoryBound(to: UInt8.self), count: width * height))
        return PictureSignals.detailFactor(pixels: pixels, width: width, height: height)
    }
}
