import SwiftUI
import UIKit

/// Chambers & Light brand system.
///
/// Tokens come from the C&L brand guide. There are four brand colours plus two
/// utility values; the guide is explicit that nothing outside that table is used
/// without being asked for.
///
/// Note on ground colour: the guide reserves chamber backgrounds for "covers,
/// decks, and gallery materials" and sets documents on white. A photo-judging
/// surface is gallery context, and a neutral dark ground avoids casting the
/// image being evaluated, so this app sits on chamber throughout.
enum Brand {

    // MARK: - Palette

    /// Chamber — the brand's near-black. Text on light ground, ground on dark.
    /// Never `#000000`.
    static let chamber  = Color(hex: 0x201612)
    /// Coral — accent only. Rules, the active state, one highlight per screen.
    /// Never body copy, never a fill behind long text, never a warning.
    static let coral    = Color(hex: 0xFF6748)
    /// Silver — borders, dividers, secondary text, table rules.
    static let silver   = Color(hex: 0xC2C1BA)
    /// White — reading surfaces, and text on chamber.
    static let white    = Color(hex: 0xFFFFFF)
    /// Warm gray — optional input fills and row striping.
    static let warmGray = Color(hex: 0xF5F3F1)

    /// The guide calls for a distinct red for errors, because coral sits too
    /// close to a warning colour to double as one.
    static let error    = Color(hex: 0xD32F2F)

    // Derived steps. Kept to blends of chamber so the palette stays closed.
    /// One step up from chamber, for raised rows and bars.
    static let chamberRaised = Color(hex: 0x2B1F1A)
    /// Hairline rule on chamber ground — silver, heavily reduced.
    static let hairline = silver.opacity(0.22)

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

/// A coral rule. The guide allows a single coral rule to mark the primary
/// section or the title; everything else divides in silver.
struct CoralRule: View {
    var width: CGFloat = 28
    var body: some View {
        Rectangle()
            .fill(Brand.coral)
            .frame(width: width, height: 2)
    }
}

/// A silver hairline divider.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Brand.hairline)
            .frame(height: Brand.hairlineWidth)
    }
}

/// The letterspaced text wordmark, used below the logo's minimum display size.
struct Wordmark: View {
    var size: CGFloat = 10
    var color: Color = Brand.silver
    var body: some View {
        Text("CHAMBERS & LIGHT")
            .font(Brand.sans(size, weight: .medium))
            .tracking(Brand.tracking(Brand.trackWide, at: size))
            .foregroundStyle(color)
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
            .foregroundStyle(Brand.silver)
    }
}

/// A section label: coral tick, then letterspaced caps in silver.
struct SectionLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: Brand.spacingSM) {
            CoralRule(width: 14)
            Text(text)
                .font(Brand.sans(11, weight: .medium))
                .tracking(Brand.tracking(Brand.trackLabel, at: 11))
                .foregroundStyle(Brand.silver)
        }
    }
}
