import SwiftUI
import AppKit

/// Chambers & Light brand system.
///
/// Tokens come from the C&L brand guide: four colours, one sans, one mono.
/// Nothing outside that table is used.
///
/// Two layers, two sets of rules. The content layer — the photograph, its
/// readouts, the batch list — follows the guide: chamber ground, tight
/// corners, hairlines, no shadows or gradients. The toolbar and inspector that
/// frame it are the system's Liquid Glass, with the system's shapes; the brand
/// reaches them only as the coral tint on the primary action.
enum Brand {

    // MARK: - Palette

    /// Chamber · the brand's near-black. Never `#000000`.
    static let chamber  = Color(hex: "#201612")
    /// Coral · accent only: rules, the active state, the primary action.
    static let coral    = Color(hex: "#FF6748")
    /// Silver · borders, dividers, secondary text.
    static let silver   = Color(hex: "#C2C1BA")
    /// White · text on chamber.
    static let white    = Color(hex: "#FFFFFF")
    /// Errors get their own red: coral sits too close to a warning colour to
    /// double as one.
    static let error    = Color(hex: "#D32F2F")

    /// Hairline rule on chamber ground: silver, heavily reduced.
    static let edgeLight = silver.opacity(0.22)

    // MARK: - Semantic aliases
    //
    // The views bind to these, so the palette can change in one place.

    static let backgroundPrimary   = chamber
    static let backgroundSecondary = Color(hex: "#2B1F1A")   // chamber, one step raised
    static let surface             = Color(hex: "#2B1F1A")
    static let surfaceElevated     = Color(hex: "#362822")   // chamber, two steps raised
    static let accent              = coral
    static let textPrimary         = white
    static let textSecondary       = silver
    static let textTertiary        = silver.opacity(0.6)
    static let border              = edgeLight
    static let success             = silver
    static let danger              = error

    // MARK: - Typography
    //
    // One sans family carries display and body; a monospace is used sparingly
    // for figures, in the manner of frame-edge markings.

    private static let displayStack = ["Neue Haas Grotesk Display Pro", "Helvetica Neue", "Inter"]
    private static let groteskStack = ["Neue Haas Grotesk Text Pro", "Helvetica Neue", "Inter"]
    private static let monoStack    = ["Space Mono", "IBM Plex Mono", "Menlo"]

    /// Returns the first installed face in `names`, falling back to the system face.
    private static func resolve(_ names: [String],
                                size: CGFloat,
                                weight: Font.Weight,
                                fallback design: Font.Design) -> Font {
        for name in names where NSFont(name: name, size: size) != nil {
            return .custom(name, fixedSize: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: design)
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        resolve(displayStack, size: size, weight: weight, fallback: .default)
    }

    static func grotesk(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        resolve(groteskStack, size: size, weight: weight, fallback: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        resolve(monoStack, size: size, weight: weight, fallback: .monospaced)
    }

    // Convenience roles
    static let fontWordmark = display(20, weight: .regular)
    static let fontHeading  = grotesk(13, weight: .semibold)
    static let fontBody     = grotesk(13)
    static let fontCaption  = grotesk(11)
    static let fontMicro    = grotesk(9,  weight: .semibold)
    static let fontMono     = mono(12)

    // MARK: - Tracking
    //
    // The guide sets headings between .05em and .15em. SwiftUI tracking is
    // absolute, so these are expressed as a multiple of the type size at call sites.

    static func tracking(_ em: CGFloat, at size: CGFloat) -> CGFloat { em * size }

    static let trackWordmark: CGFloat = 0.15   // em — the wordmark
    static let trackLabel:    CGFloat = 0.10   // em — section labels
    static let trackMeta:     CGFloat = 0.05   // em — metadata rows

    // MARK: - Metrics

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    /// The brand uses hairlines and square corners; radii stay tight.
    static let radiusSM: CGFloat = 2
    static let radiusMD: CGFloat = 3
    static let radiusLG: CGFloat = 4

}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Brand devices

/// A coral rule, used to open a section.
struct SafelightRule: View {
    var width: CGFloat = 26
    var body: some View {
        Rectangle()
            .fill(Brand.coral)
            .frame(width: width, height: 2)
    }
}

/// A coral dot marking a live or active state.
struct SafelightDot: View {
    var size: CGFloat = 8
    var body: some View {
        Circle()
            .fill(Brand.coral)
            .frame(width: size, height: size)
    }
}

/// The letterspaced text wordmark.
struct Wordmark: View {
    var size: CGFloat = 8
    var color: Color = Brand.silver
    var body: some View {
        Text("CHAMBERS & LIGHT")
            .font(Brand.grotesk(size, weight: .semibold))
            .tracking(Brand.tracking(Brand.trackWordmark, at: size))
            .foregroundColor(color)
    }
}
