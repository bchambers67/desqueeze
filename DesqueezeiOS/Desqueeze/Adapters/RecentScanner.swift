import DesqueezeCore
import Foundation
import ImageIO
import Photos

/// Looks through recent photos for ones that still need correcting.
///
/// This is the one part of the app that reads the library, so it runs only
/// when the owner has switched it on and granted access. Everything happens on
/// the device: photos are read, measured and left where they are.
enum RecentScanner {

    struct Found: Identifiable, Sendable, Equatable {
        /// The asset's identifier in the photo library.
        let id: String
        let name: String
        /// `nil` when the photo is squeezed but nothing says by how much.
        let factor: Double?
    }

    static var hasAccess: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// Photos from the last `days` that look squeezed, newest first, and the
    /// identifiers of those examined and found ordinary, so they need not be
    /// examined again.
    static func scan(days: Int = 14, limit: Int = 60, skipping handled: Set<String>,
                     corrections: [PictureSignals.Correction] = []) async -> (found: [Found], ordinary: [String]) {
        var found: [Found] = []
        var ordinary: [String] = []

        for candidate in recent(days: days, limit: limit) where !handled.contains(candidate.id) {
            guard !Task.isCancelled else { break }
            if candidate.isScreenshot || candidate.isEdited {
                ordinary.append(candidate.id)
                continue
            }
            // Photos still in iCloud are skipped for now, not written off:
            // scanning must not start downloads.
            guard let data = await data(for: candidate.id, allowNetwork: false) else { continue }

            // A photo from the same few minutes as one the owner corrected
            // needs no further reading.
            let session = candidate.taken.flatMap {
                PictureSignals.sessionFactor(taken: $0, size: candidate.size, corrections: corrections)
            }
            let picture = session == nil ? await PictureReader.readings(for: data) : PictureReader.Readings()
            let faces = session == nil ? await FaceEstimator.suggestion(for: data) : nil

            let facts = PhotoFacts(
                name: candidate.name, size: candidate.size, lensModel: lensModel(in: data),
                faceFactor: faces, textFactor: picture.text, bodyFactor: picture.body,
                detailFactor: picture.detail, sessionFactor: session,
                isScreenshot: false, isEdited: false)

            if let verdict = SqueezeDetector.verdict(for: facts) {
                found.append(Found(id: candidate.id, name: candidate.name ?? "Photo.jpg", factor: verdict.factor))
            } else {
                ordinary.append(candidate.id)
            }
        }
        return (found, ordinary)
    }

    /// A photo's bytes, as it currently stands in the library.
    static func data(for id: String, allowNetwork: Bool) async -> Data? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = allowNetwork
        options.deliveryMode = .highQualityFormat
        options.version = .current
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    /// What a corrected photo teaches the scan: when it was taken, its size
    /// and the factor used on it.
    static func correction(for id: String, factor: Double) -> PictureSignals.Correction? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject,
              let taken = asset.creationDate else { return nil }
        return PictureSignals.Correction(taken: taken, size: PixelSize(width: asset.pixelWidth, height: asset.pixelHeight), factor: factor)
    }

    // MARK: - Reading the library

    private struct Candidate {
        let id: String
        let name: String?
        let size: PixelSize
        let taken: Date?
        let isScreenshot: Bool
        let isEdited: Bool
    }

    private static func recent(days: Int, limit: Int) -> [Candidate] {
        let options = PHFetchOptions()
        let since = Date().addingTimeInterval(-Double(days) * 86_400)
        options.predicate = NSPredicate(format: "creationDate > %@", since as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit

        var candidates: [Candidate] = []
        PHAsset.fetchAssets(with: .image, options: options).enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            candidates.append(Candidate(
                id: asset.localIdentifier,
                name: resources.first { $0.type == .photo }?.originalFilename,
                size: PixelSize(width: asset.pixelWidth, height: asset.pixelHeight),
                taken: asset.creationDate,
                isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                isEdited: resources.contains { $0.type == .adjustmentData }))
        }
        return candidates
    }

    /// The lens as the camera wrote it, read from the file's header without
    /// decoding the picture.
    private static func lensModel(in data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let aux = properties[kCGImagePropertyExifAuxDictionary] as? [CFString: Any]
        let parts = [exif?[kCGImagePropertyExifLensMake] as? String,
                     exif?[kCGImagePropertyExifLensModel] as? String,
                     aux?[kCGImagePropertyExifAuxLensModel] as? String]
        let joined = parts.compactMap { $0 }.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }
}
