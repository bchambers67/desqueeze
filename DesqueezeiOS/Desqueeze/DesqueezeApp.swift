import SwiftUI

@main
struct DesqueezeApp: App {
    /// Owned here, above every view, so a fold cannot take it down.
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                // An image file handed over by Files, Mail or another app.
                // Each time the app comes forward, look for newly saved
                // photos that need correcting, if that is switched on.
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active { Task { await model.scanRecent() } }
                }
                .onOpenURL { url in
                    Task { await model.open(url) }
                }
        }
    }
}
