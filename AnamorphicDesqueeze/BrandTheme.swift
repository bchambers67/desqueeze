import SwiftUI

enum Brand {
    static let backgroundPrimary  = Color(hex: "#0D0D0D")
    static let backgroundSecondary = Color(hex: "#1A1A1A")
    static let surface             = Color(hex: "#242424")
    static let surfaceElevated     = Color(hex: "#2E2E2E")
    static let accent              = Color(hex: "#C9A84C")
    static let textPrimary         = Color(hex: "#F5F0E8")
    static let textSecondary       = Color(hex: "#8A8580")
    static let textTertiary        = Color(hex: "#4A4845")
    static let border              = Color(hex: "#333330")
    static let success             = Color(hex: "#5A9E6A")
    static let danger              = Color(hex: "#C9504C")

    static let fontHeading  = Font.system(size: 13, weight: .semibold)
    static let fontBody     = Font.system(size: 13, weight: .regular)
    static let fontCaption  = Font.system(size: 11, weight: .regular)
    static let fontMono     = Font.system(size: 12, weight: .regular, design: .monospaced)

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    static let radiusSM: CGFloat = 4
    static let radiusMD: CGFloat = 8
    static let radiusLG: CGFloat = 12
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
