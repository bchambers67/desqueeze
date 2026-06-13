import Foundation
import AppKit

/// Shared state for receiving file-open events from external editors
/// (Lightroom CC / Classic "Edit In…", Finder "Open With", etc.).
///
/// Populated by `AppDelegate.application(_:open:)` and consumed by `ContentView`
/// on appear / on change.
@MainActor
final class ExternalEditState: ObservableObject {
    @Published var pendingURL: URL?
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let externalEdit = ExternalEditState()

    nonisolated func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in
            externalEdit.pendingURL = url
        }
    }
}
