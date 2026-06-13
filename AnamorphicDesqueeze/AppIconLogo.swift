import SwiftUI
import AppKit

/// Renders the current app icon at a given size. Falls back to a static
/// asset lookup if the app's dock icon isn't available (e.g. SwiftUI previews).
struct AppIconLogo: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private var icon: NSImage {
        if let running = NSApplication.shared.applicationIconImage {
            return running
        }
        return NSImage(named: "AppIcon") ?? NSImage()
    }
}
