import Foundation

/// Anamorphic squeeze factors, in lockstep with the macOS and Windows clients.
enum SqueezePreset: String, CaseIterable, Identifiable, Sendable {
    case x125, x133, x150, x155, x160, x165, x175, x180, x200, custom

    var id: String { rawValue }

    /// `nil` for `.custom`, whose value comes from the entry field.
    var factor: Double? {
        switch self {
        case .x125: 1.25
        case .x133: 1.33
        case .x150: 1.50
        case .x155: 1.55
        case .x160: 1.60
        case .x165: 1.65
        case .x175: 1.75
        case .x180: 1.80
        case .x200: 2.00
        case .custom: nil
        }
    }

    var label: String {
        guard let f = factor else { return "Custom" }
        return String(format: "%.2f×", f)
    }

    /// The glass each factor corresponds to. Shown as a frame-edge annotation.
    var hint: String {
        switch self {
        case .x125: "ULTRA STARLESS"
        case .x133: "HAWK · LOMO"
        case .x150: "SLR MAGIC"
        case .x155: "IRON GLASS"
        case .x160: "VAZEN"
        case .x165: "COOKE SF"
        case .x175: "ATLAS MERCURY"
        case .x180: "KOWA · ISCO"
        case .x200: "FULL 2× GLASS"
        case .custom: ""
        }
    }

    /// Presets offered as rows; `.custom` is presented separately.
    static var selectable: [SqueezePreset] {
        allCases.filter { $0 != .custom }
    }
}
