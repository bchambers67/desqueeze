import Photos
import UIKit

/// Writes a finished frame to the user's photo library.
///
/// Uses `addOnly` authorisation: the app writes new images and never reads the
/// library, so requesting read access would be asking for more than the feature
/// needs. `PhotosPicker` supplies images without any authorisation at all.
enum PhotoLibraryWriter {

    enum Failure: LocalizedError {
        case denied

        var errorDescription: String? {
            switch self {
            case .denied:
                "Desqueeze needs permission to add photos. Enable it in Settings › Privacy › Photos."
            }
        }
    }

    static func save(jpeg data: Data, named name: String? = nil) async throws {
        let status = await requestAddOnlyAccess()
        guard status == .authorized || status == .limited else { throw Failure.denied }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = name
            request.addResource(with: .photo, data: data, options: options)
        }
    }

    private static func requestAddOnlyAccess() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else { return current }
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
}
