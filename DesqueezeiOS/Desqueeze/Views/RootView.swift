import SwiftUI
import PhotosUI

/// Root layout.
///
/// The Duo presents two very different canvases — a 5.4" outer display folded
/// and a 7.6" inner display open — and switches between them live. Rather than
/// branch on device or on measured point sizes, this branches on the horizontal
/// size class, which is what actually changes, and which also covers iPad and
/// every future geometry without modification.
///
/// Apple publishes no hinge-state or fold API, so nothing here reads one.
struct RootView: View {
    @State private var model = EditorModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWide: Bool { horizontalSizeClass == .regular }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if isWide {
                    wideLayout
                } else {
                    narrowLayout
                }
            }
            .background(Brand.chamber)
            // Track the surface actually in use so preview renders are sized
            // for it; this fires again when the device is folded or unfolded.
            .onChange(of: proxy.size, initial: true) { _, size in
                model.updatePreviewBudget(
                    forLongestEdge: max(size.width, size.height),
                    scale: UIScreen.main.scale
                )
            }
            // The fold is an animated resize; matching it keeps the panes from
            // snapping into place a frame late.
            .animation(.smooth(duration: 0.28), value: isWide)
        }
        .preferredColorScheme(.dark)
        .tint(Brand.coral)
    }

    // MARK: - Unfolded: image and controls side by side

    private var wideLayout: some View {
        HStack(spacing: 0) {
            PreviewPane(model: model)
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Brand.hairline)
                .frame(width: Brand.hairlineWidth)

            ControlsPane(model: model)
                .frame(width: 320)
        }
    }

    // MARK: - Folded: image above, controls beneath

    private var narrowLayout: some View {
        VStack(spacing: 0) {
            PreviewPane(model: model)
                .frame(maxHeight: .infinity)

            Hairline()

            ControlsPane(model: model)
                .frame(maxHeight: 340)
        }
    }
}
