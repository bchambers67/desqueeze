import SwiftUI
import UIKit

/// Chambers & Light brand system, in its green register.
///
/// The colours are the ones published at chambersandlight.com: pine for the
/// ground, halide for the accent, paper for type. They replace the earlier
/// chamber-and-coral scheme. Tokens are named for what they do, not what
/// colour they are, so the scheme can change here without touching a view.
///
/// Two layers, two sets of rules. The content layer, the photograph and the
/// batch grid, keeps square corners, hairlines and no shadows or gradients.
/// The control layer that floats above it is the system's Liquid Glass, with
/// the system's shapes; the brand reaches it only as the accent on the
/// primary action.
enum Brand {

    // MARK: - Palette

    /// Pine: the ground. A deep green-black, never `#000000`.
    static let ground  = Color(hex: 0x1C2723)
    /// Halide: the accent. The active state, the primary action, one
    /// highlight per screen. It is pale, so anything set on it is `ground`.
    static let accent  = Color(hex: 0xC7D9CE)
    /// Halide, deep: secondary text, borders and dividers.
    static let secondary = Color(hex: 0x98B1A3)
    /// Paper: primary text on the ground.
    static let primary = Color(hex: 0xECEAE1)

    /// Safelight red, for errors only. It is the one warm colour left, so it
    /// cannot be mistaken for anything else.
    static let error   = Color(hex: 0xE63E2D)

    // Derived steps, kept to blends of the ground so the palette stays closed.
    /// One step up from the ground, for raised rows and bars.
    static let groundRaised = Color(hex: 0x26332E)
    /// Hairline rule on the ground.
    static let hairline = secondary.opacity(0.28)

    // MARK: - Typography
    //
    // One sans family carries display and body; a monospace is used sparingly
    // for metadata, in the manner of frame-edge markings.

    private static let sansStack = [
        "NeueHaasGrotesk-Display", "NeueHaasGroteskDisplay-55Roman",
        "HelveticaNeue", "Inter-Regular",
    ]
    private static let monoStack = [
        "SpaceMono-Regular", "IBMPlexMono", "Courier New",
    ]

    /// First installed face in `names`, else the system face.
    private static func resolve(_ names: [String],
                                size: CGFloat,
                                weight: Font.Weight,
                                fallback design: Font.Design) -> Font {
        for name in names where UIFont(name: name, size: size) != nil {
            return .custom(name, fixedSize: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: design)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        resolve(sansStack, size: size, weight: weight, fallback: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        resolve(monoStack, size: size, weight: weight, fallback: .monospaced)
    }

    // MARK: - Tracking
    //
    // The guide sets headings between .05em and .15em. SwiftUI tracking is
    // absolute, so it is expressed against the type size at the call site.

    static func tracking(_ em: CGFloat, at size: CGFloat) -> CGFloat { em * size }

    static let trackWide:  CGFloat = 0.15   // em — the wordmark and screen titles
    static let trackLabel: CGFloat = 0.10   // em — section labels
    static let trackMeta:  CGFloat = 0.05   // em — metadata and captions

    // MARK: - Metrics

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    /// "Square corners on every box, table, image frame, and button."
    /// Declared so the intent is visible at call sites rather than implied by a
    /// bare zero.
    static let cornerRadius: CGFloat = 0

    /// Hairline rules are 0.5–0.75pt in print; on screen this is the thinnest
    /// line that survives on a 3x display.
    static let hairlineWidth: CGFloat = 1.0 / 3.0
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Brand devices

/// A short accent rule, used once to mark the primary section or title.
struct AccentRule: View {
    var width: CGFloat = 28
    var body: some View {
        Rectangle()
            .fill(Brand.accent)
            .frame(width: width, height: 2)
    }
}

/// A hairline divider.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Brand.hairline)
            .frame(height: Brand.hairlineWidth)
    }
}

/// A frame-edge style annotation, after the "C&L · 36A" markings on the logo.
struct FrameMark: View {
    let text: String
    var size: CGFloat = 10
    var body: some View {
        Text(text)
            .font(Brand.mono(size))
            .tracking(Brand.tracking(Brand.trackMeta, at: size))
            .foregroundStyle(Brand.secondary)
    }
}

/// A section label: accent tick, then letterspaced caps.
struct SectionLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: Brand.spacingSM) {
            AccentRule(width: 14)
            Text(text)
                .font(Brand.sans(11, weight: .medium))
                .tracking(Brand.tracking(Brand.trackLabel, at: 11))
                .foregroundStyle(Brand.secondary)
        }
    }
}
