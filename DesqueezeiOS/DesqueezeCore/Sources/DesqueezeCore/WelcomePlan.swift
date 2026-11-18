import Foundation

/// What to show a person when the app opens: what is new in this version,
/// and the tour of the features.
///
/// A first launch gets both. After an update they see what is new, and the
/// tour only if they never had it. Opening the same version again shows
/// nothing.
public struct WelcomePlan: Equatable, Sendable {
    public var showsWhatsNew: Bool
    public var showsTour: Bool

    public var isEmpty: Bool { !showsWhatsNew && !showsTour }

    public init(showsWhatsNew: Bool, showsTour: Bool) {
        self.showsWhatsNew = showsWhatsNew
        self.showsTour = showsTour
    }

    /// Both, for when a person asks to see them again.
    public static let everything = WelcomePlan(showsWhatsNew: true, showsTour: true)

    /// - Parameters:
    ///   - version: the version now running.
    ///   - lastSeenVersion: the version whose welcome was last finished, or `nil` on a first launch.
    ///   - tourSeen: whether the tour has been finished or skipped before.
    public static func forLaunch(version: String, lastSeenVersion: String?, tourSeen: Bool) -> WelcomePlan {
        let isNewVersion = lastSeenVersion != version
        return WelcomePlan(showsWhatsNew: isNewVersion, showsTour: isNewVersion && !tourSeen)
    }
}
