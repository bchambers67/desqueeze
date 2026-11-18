import SwiftUI
import UIKit

/// Rounded corners for displays that have none.
///
/// A phone or iPad with rounded screen corners shapes the picture itself, and
/// the layout already keeps clear of them. A Mac, an external display or an
/// iPad with a home button does not: the app would run into square corners.
/// There the whole canvas is clipped to the corner of a macOS 26 window, a
/// continuous curve, and sits on black behind it, so it reads as a window
/// and the controls at the bottom stay inside the curve.
///
/// Apple publishes no property for a display's own corner shape, so this goes
/// by what is published: whether it is an iOS app running on a Mac, and, on
/// iPad, whether the bottom edge needs room for a home indicator, which only
/// rounded displays have.
@MainActor
enum DisplayCorners {
    /// The corner of a macOS 26 window with toolbar controls, in points.
    static let windowRadius: CGFloat = 26

    /// The radius to clip the canvas to now: the window's on a square-cornered
    /// display, none elsewhere.
    static func radius() -> CGFloat {
        guard isSquare() else { return 0 }
        // An iOS app on a Mac is drawn at 77% ("scaled to match iPad"), so a
        // point of the app is 0.77 of a Mac point. The window's radius is in
        // Mac points; in the app's own points it is larger.
        return ProcessInfo.processInfo.isiOSAppOnMac ? windowRadius / macScale : windowRadius
    }

    private static let macScale: CGFloat = 0.77

    private static func isSquare() -> Bool {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        if ProcessInfo.processInfo.isiOSAppOnMac {
            // A Mac window already has the system's corners. Only a full-screen
            // one fills the display with square ones.
            return scene?.isFullScreen ?? false
        }
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        return (scene?.keyWindow?.safeAreaInsets.bottom ?? 1) == 0
    }
}

private struct DisplayCornerRadiusKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// The corner radius the canvas is clipped to, or 0 when the display
    /// supplies its own corners. Controls near a corner read it to sit
    /// concentric with it.
    var displayCornerRadius: CGFloat {
        get { self[DisplayCornerRadiusKey.self] }
        set { self[DisplayCornerRadiusKey.self] = newValue }
    }
}
