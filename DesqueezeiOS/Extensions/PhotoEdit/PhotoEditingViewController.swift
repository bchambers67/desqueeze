import Photos
import PhotosUI
import SwiftUI
import UIKit

/// StillScope inside the Photos app: Edit, the extensions button, StillScope.
///
/// The correction is saved onto the photo itself. Photos keeps the original,
/// so the edit can be reverted there, and the factor is stored with the photo
/// so opening it here again starts from the same value.
final class PhotoEditingViewController: UIViewController, PHContentEditingController {
    private static let format = "com.chambersandlight.stillscope.squeeze"

    private let model = QuickEditModel()
    private var input: PHContentEditingInput?
    private var openingFactor = 2.0

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: QuickEditor(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    // MARK: - PHContentEditingController

    func canHandle(_ adjustmentData: PHAdjustmentData) -> Bool {
        adjustmentData.formatIdentifier == Self.format
    }

    func startContentEditing(with contentEditingInput: PHContentEditingInput, placeholderImage: UIImage) {
        input = contentEditingInput
        if let saved = contentEditingInput.adjustmentData, canHandle(saved),
           let factor = Double(String(decoding: saved.data, as: UTF8.self)) {
            model.factor = factor
        }
        openingFactor = model.factor

        guard let url = contentEditingInput.fullSizeImageURL, let data = try? Data(contentsOf: url) else {
            model.fail("This photo could not be opened for editing.")
            return
        }
        Task { await model.load(data) }
    }

    func finishContentEditing(completionHandler: @escaping (PHContentEditingOutput?) -> Void) {
        guard let input else { completionHandler(nil); return }
        Task { @MainActor in
            do {
                let jpeg = try await model.export()
                let output = PHContentEditingOutput(contentEditingInput: input)
                output.adjustmentData = PHAdjustmentData(
                    formatIdentifier: Self.format, formatVersion: "1",
                    data: Data(String(format: "%.2f", model.factor).utf8))
                try jpeg.write(to: output.renderedContentURL, options: .atomic)
                completionHandler(output)
            } catch {
                completionHandler(nil)
            }
        }
    }

    var shouldShowCancelConfirmation: Bool { abs(model.factor - openingFactor) > 0.001 }

    func cancelContentEditing() {}
}
