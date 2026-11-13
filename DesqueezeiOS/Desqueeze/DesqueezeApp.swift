import SwiftUI

@main
struct DesqueezeApp: App {
    /// Owned here, above every view, so a fold cannot take it down.
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
