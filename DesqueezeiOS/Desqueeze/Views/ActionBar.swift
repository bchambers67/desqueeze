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
    let panelShown: Bool

    var body: some ToolbarContent {
        // Grouped by what they act on: the queue, the correction, the result.
        // Icon items share a background; the factor is text, so it sits alone.
        ToolbarItemGroup(placement: .bottomBar) {
            PhotosButton(model: model)
            if model.hasContent { ClearButton(model: model) }
            if model.findsSqueezed { RescanButton(model: model) }
            SettingsButton(model: model)
        }
        ToolbarSpacer(.flexible, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            FactorButton(model: model, panelShown: panelShown)
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
    let panelShown: Bool
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
                    if model.findsSqueezed { RescanButton(model: model) }
                    SettingsButton(model: model)
                }
                .buttonStyle(.glass)

                Spacer(minLength: 0)

                FactorButton(model: model, panelShown: panelShown, iconOnly: true)
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
        PhotosPicker(selection: $picked, maxSelectionCount: AppModel.batchLimit, matching: .images, photoLibrary: .shared()) {
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

/// Checks recent photos again for ones that need correcting. It appears only
/// while that feature is switched on in Settings.
private struct RescanButton: View {
    let model: AppModel

    var body: some View {
        Button {
            Task { await model.rescan() }
        } label: {
            if model.isScanning {
                ProgressView()
            } else {
                Label("Check recent photos", systemImage: "arrow.triangle.2.circlepath")
                    .labelStyle(.iconOnly)
            }
        }
        .disabled(model.isScanning || model.isWorking)
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

/// The squeeze factor control's button: it opens and closes the factor panel.
///
/// Along the bottom it shows the factor. In the side bar there is no room for
/// a number, so it is a symbol, a frame opening outward from its centre line,
/// and the panel shows the number.
private struct FactorButton: View {
    let model: AppModel
    let panelShown: Bool
    var iconOnly = false

    var body: some View {
        Button {
            model.factorPanelChoice = !panelShown
        } label: {
            if iconOnly {
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
        // Lit while its panel is open, as the one thing that closes it.
        .foregroundStyle(panelShown ? Brand.accent : Brand.primary)
        .accessibilityLabel("Squeeze factor")
        .accessibilityValue(String(format: "%.2f", model.session.squeeze.factor))
        .accessibilityAddTraits(panelShown ? .isSelected : [])
        .disabled(model.isWorking)
    }
}

/// The slider wired to the session: the factor it shows is the session's, and
/// moving it re-renders.
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

struct SheetDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Done")
                .font(Brand.sans(15, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.bordered)
        .tint(Brand.primary)
    }
}

/// Sizes a sheet to the height of its content.
private struct FittedSheet: ViewModifier {
    @State private var height: CGFloat = 220

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .presentationDetents([.height(height)])
    }
}

extension View {
    func fittedSheet() -> some View { modifier(FittedSheet()) }
}

/// The factor slider in a glass panel above the action bar.
///
/// It is part of the screen, not a sheet over it: the bar stays in reach
/// below, the photograph stays in view above, and the panel takes the space
/// between. It grows out of the factor button that opens it, the way a folder
/// opens on the Home Screen, and shrinks back into it.
struct FactorPanel: View {
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

/// How the panel arrives and leaves: scaled up from the button, sharpening
/// and fading in as it grows.
struct ZoomFromButton: ViewModifier {
    let progress: Double
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .scaleEffect(0.12 + 0.88 * progress, anchor: anchor)
            .opacity(progress)
            .blur(radius: (1 - progress) * 10)
    }
}

extension AnyTransition {
    static func zoom(from anchor: UnitPoint) -> AnyTransition {
        .modifier(active: ZoomFromButton(progress: 0, anchor: anchor),
                  identity: ZoomFromButton(progress: 1, anchor: anchor))
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
            // The accent is pale, so what sits on it is the dark ground.
            if model.isWorking {
                ProgressView().tint(Brand.ground)
            } else {
                Label(model.mode == .batch ? "Save all to library" : "Save to library",
                      systemImage: "square.and.arrow.down")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Brand.ground)
            }
        }
        .tint(Brand.accent)
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
                .foregroundStyle(notice.isError ? Brand.error : Brand.primary)
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
