import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// StillScope in the share sheet of any app that shares a photo.
///
/// The photo is corrected here and saved to the library, without leaving the
/// app it was shared from.
final class ShareViewController: UIViewController {
    private let model = QuickEditModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let editor = QuickEditor(
            model: model, actionTitle: "Save to Photos",
            cancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
            },
            action: { [weak self] in self?.save() })
        let host = UIHostingController(rootView: editor)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        loadSharedImage()
    }

    private func loadSharedImage() {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else {
            model.fail("Nothing shared here is a photo.")
            return
        }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
            Task { @MainActor in
                guard let self else { return }
                if let data {
                    await self.model.load(data)
                } else {
                    self.model.fail("That photo could not be loaded.")
                }
            }
        }
    }

    private func save() {
        Task { @MainActor in
            do {
                let jpeg = try await model.export()
                let name = String(format: "desqueeze_%.2fx.jpg", model.factor)
                try await PhotoLibraryWriter.save(jpeg: jpeg, named: name)
                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                model.fail(error.localizedDescription)
            }
        }
    }
}
