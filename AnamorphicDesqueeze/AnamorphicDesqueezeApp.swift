import SwiftUI

@main
struct AnamorphicDesqueezeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.externalEdit)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            // Remove "New Window" from File menu — this is a single-document tool
            CommandGroup(replacing: .newItem) { }
        }
    }
}
