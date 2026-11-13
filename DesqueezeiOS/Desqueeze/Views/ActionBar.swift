import DesqueezeCore
import PhotosUI
import SwiftUI
import UIKit

/// Which edge the action bar sits on.
enum BarEdge {
    case bottom, trailing

    /// An open iPhone Duo gets the bar down its right side; everything else
    /// gets it along the bottom.
    ///
    /// Apple publishes no API that says "this is a Duo" or "it is open", and
    /// does not publish its size classes, so this goes by the one thing that
    /// is published: the inner display is 1878 pixels on its short side, about
    /// 626 points, where the widest slab iPhone is 440. A phone whose window
    /// is at least `openDuoShortSide` points on its short side can only be an
    /// open Duo. Folded, its outer display is narrower than that, and the bar
    /// returns to the bottom.
    @MainActor
    static func resolve(for size: CGSize, idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> BarEdge {
        idiom == .phone && min(size.width, size.height) >= openDuoShortSide ? .trailing : .bottom
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

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(spacing: 14) {
                Group {
                    PhotosButton(model: model)
                    if model.hasContent { ClearButton(model: model) }
                }
                .buttonStyle(.glass)

                Spacer(minLength: 0)

                FactorButton(model: model)
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
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
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

/// The squeeze factor: shows the current value, and opens the factor sheet.
private struct FactorButton: View {
    let model: AppModel

    var body: some View {
        Button {
            model.isChoosingFactor = true
        } label: {
            Text(String(format: "%.2f×", model.session.squeeze.factor))
                .font(Brand.mono(15, weight: .medium))
                .monospacedDigit()
                .padding(.horizontal, 4)
        }
        .accessibilityLabel("Squeeze factor")
        .accessibilityValue(String(format: "%.2f", model.session.squeeze.factor))
        .disabled(model.isWorking)
    }
}

/// The factor, on a slider, in a short sheet that leaves the photo in view.
struct FactorSheet: View {
    let model: AppModel
    @State private var factor: Double

    init(model: AppModel) {
        self.model = model
        _factor = State(initialValue: FactorSlider.clamped(model.session.squeeze.factor))
    }

    private var hasSuggestion: Bool { model.mode == .single && model.suggestion != nil }

    var body: some View {
        VStack(spacing: 16) {
            if hasSuggestion, let suggestion = model.suggestion {
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
        .padding(20)
        .onChange(of: factor) { _, new in
            Task { await model.use(factor: new) }
        }
        // The suggestion changes the factor from outside the slider.
        .onChange(of: model.session.squeeze.factor) { _, new in
            if abs(new - factor) > 0.004 { factor = FactorSlider.clamped(new) }
        }
        .presentationDetents([.height(hasSuggestion ? 270 : 200)])
        .presentationBackgroundInteraction(.enabled)
        .presentationDragIndicator(.visible)
    }
}

/// A squeeze factor on a slider, with the lens presets as its stop points.
///
/// The slider moves in hundredths. Each preset is marked beneath the track,
/// and arriving on one gives a light selection tap, so the common factors can
/// be found by feel while every value in between stays reachable.
struct FactorSlider: View {
    @Binding var factor: Double

    static let range: ClosedRange<Double> = 1.0...2.0
    static let stops: [SqueezePreset] = SqueezePreset.selectable.filter { $0.factor != nil }

    static func clamped(_ value: Double) -> Double {
        let bounded = min(max(value, range.lowerBound), range.upperBound)
        return (bounded * 100).rounded() / 100
    }

    /// The preset the thumb is resting on, if any.
    private var stop: SqueezePreset? {
        Self.stops.first { abs(($0.factor ?? 0) - factor) < 0.005 }
    }

    /// Roughly half the system thumb: how far the track's ends sit inside the
    /// slider's frame.
    private let trackInset: CGFloat = 14
    private let labelled: Set<SqueezePreset> = [.x133, .x150, .x175, .x200]

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.2f×", factor))
                    .font(Brand.mono(26, weight: .medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer()
                Text(stop?.hint.capitalized ?? "Custom")
                    .font(Brand.sans(12))
                    .foregroundStyle(stop == nil ? Brand.silver : Brand.coral)
            }

            HStack(spacing: 12) {
                nudge(-0.01, "minus", "Down 0.01")
                Slider(value: $factor, in: Self.range, step: 0.01) {
                    Text("Squeeze factor")
                }
                .tint(Brand.coral)
                .accessibilityValue(String(format: "%.2f", factor))
                .background(alignment: .bottom) { ticks.offset(y: 22) }
                nudge(0.01, "plus", "Up 0.01")
            }
            .padding(.bottom, 24)
        }
        // A tap on arriving at a stop point, and none on leaving it.
        .sensoryFeedback(.selection, trigger: stop) { _, new in new != nil }
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
                .frame(width: 1, alignment: .top)
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
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.bordered)
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
