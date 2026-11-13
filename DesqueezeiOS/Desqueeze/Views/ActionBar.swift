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

/// Every factor on one sheet, as targets big enough for a thumb.
///
/// Nothing here scrolls: the nine presets are a 3 × 3 grid, and a custom
/// factor is nudged with buttons rather than typed, so there is no list to
/// drag through and no keyboard to bring up.
struct FactorSheet: View {
    let model: AppModel
    private var session: Session { model.session }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 18) {
            Text(model.mode == .batch ? "Batch factor" : "Squeeze factor")
                .font(Brand.sans(15, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)

            if model.mode == .single, let suggestion = model.suggestion {
                Button {
                    Task { await model.useSuggestion() }
                } label: {
                    Label(String(format: "Use %.2f×, read from faces", suggestion), systemImage: "face.dashed")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.bordered)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(SqueezePreset.selectable) { preset in
                    tile(preset)
                }
            }

            nudger
        }
        .controlSize(.large)
        .padding(20)
        .presentationDetents([.height(model.mode == .single && model.suggestion != nil ? 470 : 410)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func tile(_ preset: SqueezePreset) -> some View {
        let label = VStack(spacing: 3) {
            Text(preset.label)
                .font(Brand.mono(17, weight: .medium))
            Text(preset.hint.capitalized)
                .font(Brand.sans(10))
                .opacity(0.75)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 48)

        // The chosen factor is the one filled, tinted control on the sheet.
        if session.preset == preset {
            Button { } label: { label }
                .buttonStyle(.borderedProminent)
                .tint(Brand.coral)
                .accessibilityAddTraits(.isSelected)
        } else {
            Button {
                Task { await session.choose(preset) }
            } label: { label }
                .buttonStyle(.bordered)
        }
    }

    /// A custom factor, nudged in hundredths or twentieths.
    private var nudger: some View {
        HStack(spacing: 10) {
            step(-0.05, "minus.circle.fill", "Down 0.05")
            step(-0.01, "minus", "Down 0.01")

            VStack(spacing: 2) {
                Text(String(format: "%.2f×", session.squeeze.factor))
                    .font(Brand.mono(20, weight: .medium))
                    .monospacedDigit()
                Text(session.preset == .custom ? "Custom" : "Fine-tune")
                    .font(Brand.sans(10))
                    .opacity(0.75)
            }
            .frame(maxWidth: .infinity)

            step(0.01, "plus", "Up 0.01")
            step(0.05, "plus.circle.fill", "Up 0.05")
        }
    }

    private func step(_ delta: Double, _ symbol: String, _ name: String) -> some View {
        Button {
            let next = ((session.squeeze.factor + delta) * 100).rounded() / 100
            Task { await model.useTyped(String(format: "%.2f", next)) }
        } label: {
            Label(name, systemImage: symbol)
                .labelStyle(.iconOnly)
                .frame(width: 30, height: 30)
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
