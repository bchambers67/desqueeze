import DesqueezeCore
import PhotosUI
import SwiftUI
import UIKit

/// Which edge the action bar sits on.
enum BarEdge {
    case bottom, trailing

    /// An open iPhone Duo held sideways gets the bar down its right side;
    /// everything else, an open Duo held upright included, gets it along the
    /// bottom.
    ///
    /// Apple publishes no API that says "this is a Duo" or "it is open", and
    /// does not publish its size classes, so this goes by the one thing that
    /// is published: the inner display is 1878 pixels on its short side, about
    /// 626 points, where the widest slab iPhone is 440. A phone whose window
    /// is at least `openDuoShortSide` points on its short side can only be an
    /// open Duo. Folded, its outer display is narrower than that.
    @MainActor
    static func resolve(for size: CGSize, idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> BarEdge {
        let isOpenDuo = idiom == .phone && min(size.width, size.height) >= openDuoShortSide
        return isOpenDuo && size.width > size.height ? .trailing : .bottom
    }

    private static let openDuoShortSide: CGFloat = 520
}

// MARK: - Bottom: the system toolbar

/// The action bar as a standard bottom toolbar. The system supplies the Liquid
/// Glass, the grouping and the scroll-edge treatment; nothing here draws a
/// background.
struct BottomBarItems: ToolbarContent {
    let model: AppModel

    var body: some ToolbarContent {
        // Grouped by what they act on: the queue, the correction, the result.
        // Icon items share a background; the factor is text, so it sits alone.
        ToolbarItemGroup(placement: .bottomBar) {
            PhotosButton(model: model)
            if model.hasContent { ClearButton(model: model) }
            SettingsButton(model: model)
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            FactorButton(model: model)
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        if model.mode == .single {
            ToolbarItemGroup(placement: .bottomBar) {
                InspectButton(model: model)
                ShareButton(model: model)
            }
            ToolbarSpacer(.fixed, placement: .bottomBar)
        }
        ToolbarItem(placement: .bottomBar) {
            SaveButton(model: model)
                .buttonStyle(.glassProminent)
        }
    }
}

// MARK: - Trailing: the same actions, stacked

/// The action bar down the trailing edge, for an open iPhone Duo.
///
/// There is no system toolbar placement for this edge, so this is the one
/// place the app builds glass itself. It uses the system's glass button
/// styles rather than a hand-made effect, and one container so the pieces
/// render, and morph, as a single layer.
struct SideBar: View {
    let model: AppModel
    /// Room left at the top for the clock and status icons, which an open Duo
    /// draws in this same strip.
    var topClearance: CGFloat = 20
    /// The bar is as wide as the strip it shares with the status icons, so
    /// its buttons centre on the same line as the clock above them.
    var width: CGFloat = SideBar.minimumWidth

    /// How far left of the strip's middle the buttons sit. The status icons
    /// are not centred in the safe-area strip: the display's rounded corner
    /// pushes them inward, and the bar follows them.
    var centreShift: CGFloat = 0

    static let minimumWidth: CGFloat = 76

    /// The bar's width and top clearance for a window's safe area.
    static func metrics(trailingInset: CGFloat) -> (width: CGFloat, topClearance: CGFloat, centreShift: CGFloat) {
        let sharesStatusStrip = trailingInset > 20
        return (max(minimumWidth, trailingInset), sharesStatusStrip ? 124 : 20, sharesStatusStrip ? 7 : 0)
    }

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(spacing: 14) {
                Group {
                    PhotosButton(model: model)
                    if model.hasContent { ClearButton(model: model) }
                    SettingsButton(model: model)
                }
                .buttonStyle(.glass)

                Spacer(minLength: 0)

                FactorButton(model: model, togglesDock: true)
                    .buttonStyle(.glass)

                Spacer(minLength: 0)

                if model.mode == .single {
                    Group {
                        InspectButton(model: model)
                        ShareButton(model: model)
                    }
                    .buttonStyle(.glass)
                }
                SaveButton(model: model)
                    .buttonStyle(.glassProminent)
            }
            .controlSize(.large)
            .buttonBorderShape(.circle)
            .padding(.top, topClearance)
            .padding(.bottom, 20)
            .padding(.trailing, centreShift * 2)
            .frame(width: width)
        }
    }
}

// MARK: - The actions

private struct PhotosButton: View {
    let model: AppModel
    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(selection: $picked, maxSelectionCount: AppModel.batchLimit, matching: .images) {
            Label("Choose photos", systemImage: "photo.on.rectangle.angled")
                .labelStyle(.iconOnly)
        }
        .disabled(model.isWorking)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await model.take(items)
                picked = []
            }
        }
    }
}

private struct ClearButton: View {
    let model: AppModel

    var body: some View {
        Button(role: .destructive) {
            model.reset()
        } label: {
            Label("Clear", systemImage: "trash").labelStyle(.iconOnly)
        }
        .disabled(model.isWorking)
    }
}

private struct SettingsButton: View {
    let model: AppModel

    var body: some View {
        Button {
            model.isShowingSettings = true
        } label: {
            Label("Settings", systemImage: "gearshape").labelStyle(.iconOnly)
        }
    }
}

/// The squeeze factor control's button.
///
/// Along the bottom it shows the factor and opens the slider in a sheet. In
/// the side bar there is no room for a number, and the slider is docked on
/// screen with the number beside it, so the button is a symbol, a frame
/// opening outward from its centre line, that shows or hides the dock.
private struct FactorButton: View {
    let model: AppModel
    var togglesDock = false

    var body: some View {
        Button {
            if togglesDock {
                model.isFactorDockShown.toggle()
            } else {
                model.isChoosingFactor = true
            }
        } label: {
            if togglesDock {
                Label("Squeeze factor", systemImage: "arrow.left.and.line.vertical.and.arrow.right")
                    .labelStyle(.iconOnly)
            } else {
                Text(String(format: "%.2f×", model.session.squeeze.factor))
                    .font(Brand.mono(15, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 4)
            }
        }
        .accessibilityLabel("Squeeze factor")
        .accessibilityValue(String(format: "%.2f", model.session.squeeze.factor))
        .disabled(model.isWorking)
    }
}

/// The slider wired to the session: the factor it shows is the session's, and
/// moving it re-renders. Used in the sheet and in the dock.
struct FactorControl: View {
    let model: AppModel
    @State private var factor: Double

    init(model: AppModel) {
        self.model = model
        _factor = State(initialValue: FactorSlider.clamped(model.session.squeeze.factor))
    }

    static func hasSuggestion(_ model: AppModel) -> Bool {
        model.mode == .single && model.suggestion != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            if Self.hasSuggestion(model), let suggestion = model.suggestion {
                Button {
                    Task { await model.useSuggestion() }
                } label: {
                    Label(String(format: "Use %.2f×, read from faces", suggestion), systemImage: "face.dashed")
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.bordered)
            }

            FactorSlider(factor: $factor)
        }
        .onChange(of: factor) { _, new in
            Task { await model.use(factor: new) }
        }
        // The suggestion changes the factor from outside the slider.
        .onChange(of: model.session.squeeze.factor) { _, new in
            if abs(new - factor) > 0.004 { factor = FactorSlider.clamped(new) }
        }
    }
}

/// The factor slider in a short sheet that leaves the photo in view.
struct FactorSheet: View {
    let model: AppModel

    var body: some View {
        FactorControl(model: model)
            .padding(20)
            // The sheet spans the screen, so its content may too. A cover
            // display reserves a strip down one side that would otherwise
            // squeeze the slider.
            .ignoresSafeArea(.container, edges: .horizontal)
            .presentationDetents([.height(FactorControl.hasSuggestion(model) ? 270 : 200)])
            .presentationBackgroundInteraction(.enabled)
            .presentationDragIndicator(.visible)
    }
}

/// The factor slider docked along the bottom, for an open iPhone Duo held
/// sideways, where there is room to keep it on screen beside the photograph.
struct FactorDock: View {
    let model: AppModel

    var body: some View {
        FactorControl(model: model)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .frame(maxWidth: 620)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
            .padding(.horizontal, Brand.spacingMD)
            .padding(.bottom, 10)
    }
}

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

private struct InspectButton: View {
    let model: AppModel

    var body: some View {
        Button {
            model.isInspecting = true
        } label: {
            Label("Inspect", systemImage: "plus.magnifyingglass").labelStyle(.iconOnly)
        }
        .disabled(!model.session.hasPhoto)
    }
}

private struct ShareButton: View {
    let model: AppModel

    var body: some View {
        Button {
            Task { await model.perform { await model.share() } }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up").labelStyle(.iconOnly)
        }
        .disabled(!model.session.hasPhoto || model.isWorking)
    }
}

/// The one tinted control: saving is what the app is for.
private struct SaveButton: View {
    let model: AppModel

    var body: some View {
        Button {
            Task {
                await model.perform {
                    if model.mode == .batch { await model.runBatch() } else { await model.saveToLibrary() }
                }
            }
        } label: {
            if model.isWorking {
                ProgressView()
            } else {
                Label(model.mode == .batch ? "Save all to library" : "Save to library",
                      systemImage: "square.and.arrow.down")
                    .labelStyle(.iconOnly)
            }
        }
        .tint(Brand.coral)
        .disabled(!model.hasContent || model.isWorking)
    }
}

// MARK: - Status

/// A suggestion or a result, shown once above the content.
struct StatusChip: View {
    let model: AppModel

    var body: some View {
        if let notice = model.notice {
            Label(notice.text, systemImage: notice.isError ? "exclamationmark.triangle" : "checkmark")
                .font(Brand.sans(13))
                .foregroundStyle(notice.isError ? Brand.error : Brand.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
                .padding(.top, 12)
                .padding(.horizontal, Brand.spacingMD)
                .transition(.opacity)
        }
    }
}

// MARK: - Share sheet

struct SharedFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// The system share sheet. `ShareLink` wants its item up front; the export is
/// rendered on demand, so the sheet is presented once the file exists.
struct ActivitySheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
