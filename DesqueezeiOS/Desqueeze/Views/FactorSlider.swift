import DesqueezeCore
import SwiftUI

/// A squeeze factor on a slider, with the lens presets as its stop points.
///
/// The thumb follows the finger, but the factor snaps to the nearest preset,
/// with a light tap on each one it lands on. Holding still between two
/// presets for two seconds lets go of the snap: from then until the finger
/// lifts, the factor follows the thumb in hundredths.
struct FactorSlider: View {
    @Binding var factor: Double

    /// Where the thumb is. The factor is this, snapped, unless the snap has
    /// been released.
    @State private var raw: Double
    @State private var isDragging = false
    @State private var isFree = false
    @State private var holdAnchor: Double?
    @State private var hold: Task<Void, Never>?

    init(factor: Binding<Double>) {
        _factor = factor
        _raw = State(initialValue: factor.wrappedValue)
    }

    static let range: ClosedRange<Double> = 1.0...2.0
    static let stops: [SqueezePreset] = SqueezePreset.selectable.filter { $0.factor != nil }
    static let holdToRelease: Duration = .seconds(2)

    static func clamped(_ value: Double) -> Double {
        let bounded = min(max(value, range.lowerBound), range.upperBound)
        return (bounded * 100).rounded() / 100
    }

    static func nearestStop(to value: Double) -> Double {
        stops.compactMap(\.factor).min { abs($0 - value) < abs($1 - value) } ?? value
    }

    /// The preset the factor is resting on, if any.
    private var stop: SqueezePreset? {
        Self.stops.first { abs(($0.factor ?? 0) - factor) < 0.005 }
    }

    /// The thumb moved under a finger.
    private func moved(to value: Double) {
        if isFree {
            factor = value
            return
        }
        let snapped = Self.nearestStop(to: value)
        factor = snapped

        // On a stop there is nothing to wait for.
        guard abs(snapped - value) > 0.005 else {
            hold?.cancel()
            holdAnchor = nil
            return
        }
        // A finger held still still trembles by a step; that is not a move.
        if let holdAnchor, abs(value - holdAnchor) < 0.015 { return }
        hold?.cancel()
        holdAnchor = value
        hold = Task {
            try? await Task.sleep(for: Self.holdToRelease)
            guard !Task.isCancelled else { return }
            isFree = true
            factor = raw
        }
    }

    private func dragChanged(_ editing: Bool) {
        isDragging = editing
        guard !editing else { return }
        hold?.cancel()
        holdAnchor = nil
        isFree = false
        raw = factor        // the thumb settles where the factor is
    }

    /// Roughly half the system thumb: how far the track's ends sit inside the
    /// slider's frame.
    private let trackInset: CGFloat = 14
    private let labelled: Set<SqueezePreset> = [.x133, .x150, .x175, .x200]

    var body: some View {
        VStack(spacing: 12) {
            // The nudges flank the readout, so the slider below has the whole
            // width to itself, which matters most on a narrow cover display.
            HStack(spacing: 12) {
                nudge(-0.01, "minus", "Down 0.01")
                VStack(spacing: 2) {
                    Text(String(format: "%.2f×", factor))
                        .font(Brand.mono(24, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(stop?.hint.capitalized ?? (isDragging && !isFree ? "Hold to fine-tune" : "Custom"))
                        .font(Brand.sans(12))
                        .foregroundStyle(stop == nil ? Brand.silver : Brand.coral)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                nudge(0.01, "plus", "Up 0.01")
            }

            Slider(value: $raw, in: Self.range, step: 0.01, onEditingChanged: dragChanged)
                .tint(Brand.coral)
                .accessibilityLabel("Squeeze factor")
                .accessibilityValue(String(format: "%.2f", factor))
                .background(alignment: .bottom) { ticks.offset(y: 24) }
                .padding(.bottom, 26)
        }
        .tint(Brand.white)
        .onChange(of: raw) { _, new in
            // A change that only mirrors the factor did not come from a finger.
            if abs(new - factor) > 0.001 || isDragging { moved(to: new) }
        }
        .onChange(of: factor) { _, new in
            if !isDragging, abs(raw - new) > 0.001 { raw = new }
        }
        .onDisappear { hold?.cancel() }
        // A tap on arriving at a stop point, and none on leaving it.
        .sensoryFeedback(.selection, trigger: stop) { _, new in new != nil }
        // A firmer one when a hold releases the snap.
        .sensoryFeedback(.impact(weight: .medium), trigger: isFree) { _, new in new }
    }

    /// A mark under the track for each preset; a tap on one jumps to it.
    private var ticks: some View {
        GeometryReader { proxy in
            let span = proxy.size.width - trackInset * 2
            ForEach(Self.stops) { preset in
                let value = preset.factor ?? 1
                let x = trackInset + span * (value - Self.range.lowerBound)
                    / (Self.range.upperBound - Self.range.lowerBound)
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(stop == preset ? Brand.coral : Brand.silver)
                        .frame(width: 1, height: 7)
                    if labelled.contains(preset) {
                        Text(String(format: "%.2f", value))
                            .font(Brand.mono(9))
                            .foregroundStyle(stop == preset ? Brand.white : Brand.silver)
                            .fixedSize()
                    }
                }
                // A fixed, top-aligned box: every mark starts on the same line
                // whether or not it carries a label, so the short marks never
                // drop into the row of figures.
                .frame(width: 1, height: 24, alignment: .top)
                .position(x: x, y: 12)
            }
        }
        .frame(height: 24)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func nudge(_ delta: Double, _ symbol: String, _ name: String) -> some View {
        Button {
            factor = Self.clamped(factor + delta)
        } label: {
            Label(name, systemImage: symbol)
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .buttonRepeatBehavior(.enabled)
    }
}
