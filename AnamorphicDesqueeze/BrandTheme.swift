import SwiftUI
import AppKit

/// Chambers & Light brand system.
///
/// Tokens mirror the authoritative definitions published at chambersandlight.com
/// (`:root` custom properties). The palette follows a darkroom metaphor: the
/// `chamber` holds the image, `paper` receives it, `halide` is the light‑sensitive
/// layer, `grain` the texture, and `safelight` the only illumination safe to work by.
enum Brand {

    // MARK: - Palette

    /// `--chamber` · warm near‑black. Primary background.
    static let chamber       = Color(hex: "#16110F")
    /// `--pine` · deep green‑black. Raised surfaces and panels.
    static let pine          = Color(hex: "#1C2723")
    /// `--paper` · warm bone. Primary text.
    static let paper         = Color(hex: "#ECEAE1")
    /// `--halide` · pale mint. Highlights and active text.
    static let halide        = Color(hex: "#C7D9CE")
    /// `--halide-deep` · sage. Secondary text.
    static let halideDeep    = Color(hex: "#98B1A3")
    /// `--grain` · warm mid grey. Tertiary text and disabled states.
    static let grain         = Color(hex: "#6E665F")
    /// `--safelight` · darkroom red. Primary accent and calls to action.
    static let safelight     = Color(hex: "#E63E2D")
    /// `--safelight-deep` · deeper red. Pressed and hover states.
    static let safelightDeep = Color(hex: "#C22E1F")

    /// `--edge-light` · hairline rule on dark ground.
    static let edgeLight     = Color(white: 0.925, opacity: 0.16)
    /// `--edge` · hairline rule on paper ground.
    static let edge          = Color(hex: "#16110F").opacity(0.14)

    // MARK: - Semantic aliases

    static let backgroundPrimary   = chamber
    static let backgroundSecondary = Color(hex: "#1A1512")   // chamber, one step raised
    static let surface             = pine
    static let surfaceElevated     = Color(hex: "#243029")   // pine, one step raised
    static let accent              = safelight
    static let textPrimary         = paper
    static let textSecondary       = halideDeep
    static let textTertiary        = grain
    static let border              = edgeLight
    static let success             = halideDeep
    static let danger              = safelight

    // MARK: - Typography

    /// `--f-display` · Bodoni Moda / Didot. Wordmark and display copy only.
    private static let displayStack = ["Bodoni Moda", "Bodoni 72", "Didot", "Georgia"]
    /// `--f-grotesk` · Archivo. All interface copy.
    private static let groteskStack = ["Archivo", "Helvetica Neue"]
    /// `--f-mono` · Space Mono. Numeric and technical readouts.
    private static let monoStack    = ["Space Mono", "Menlo", "SF Mono"]

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
        resolve(displayStack, size: size, weight: weight, fallback: .serif)
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
    // The brand sets uppercase labels between .1em and .22em. SwiftUI tracking is
    // absolute, so these are expressed as a multiple of the type size at call sites.

    static func tracking(_ em: CGFloat, at size: CGFloat) -> CGFloat { em * size }

    static let trackWordmark: CGFloat = 0.22   // em — the C H A M B E R S lockup
    static let trackLabel:    CGFloat = 0.18   // em — section labels
    static let trackMeta:     CGFloat = 0.12   // em — metadata rows

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

    /// `--ratio-pano` · 65 : 24, the house panoramic crop.
    static let ratioPano: CGFloat = 65.0 / 24.0
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

/// The safelight rule — a 26 × 2 pt bar used to open sections, per the site's
/// section-heading treatment.
struct SafelightRule: View {
    var width: CGFloat = 26
    var body: some View {
        Rectangle()
            .fill(Brand.safelight)
            .frame(width: width, height: 2)
    }
}

/// The safelight dot — an 8 pt indicator marking a live or active state.
struct SafelightDot: View {
    var size: CGFloat = 8
    var body: some View {
        Circle()
            .fill(Brand.safelight)
            .frame(width: size, height: size)
    }
}

/// The letter-spaced house lockup: C H A M B E R S  &  L I G H T
struct Wordmark: View {
    var size: CGFloat = 8
    var color: Color = Brand.halideDeep
    var body: some View {
        Text("CHAMBERS & LIGHT")
            .font(Brand.grotesk(size, weight: .semibold))
            .tracking(Brand.tracking(Brand.trackWordmark, at: size))
            .foregroundColor(color)
    }
}
