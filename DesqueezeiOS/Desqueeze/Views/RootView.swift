import SwiftUI

/// Root layout.
///
/// The Duo presents two canvases, a 5.4" outer display and a 7.6" inner one,
/// and switches between them while the app runs. This branches on the
/// horizontal size class, which is what actually changes, rather than on the
/// device or on measured points; the same branch serves iPad.
///
/// Apple publishes no hinge or fold API, so nothing here reads one.
struct RootView: View {
    let model: AppModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.displayScale) private var displayScale

    private var isWide: Bool { horizontalSizeClass == .regular }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if isWide {
                    HStack(spacing: 0) {
                        canvas.frame(maxWidth: .infinity)
                        Rectangle().fill(Brand.hairline).frame(width: Brand.hairlineWidth)
                        ControlsPane(model: model).frame(width: 330)
                    }
                } else {
                    VStack(spacing: 0) {
                        canvas.frame(maxHeight: .infinity)
                        Hairline()
                        ControlsPane(model: model).frame(maxHeight: proxy.size.height * 0.46)
                    }
                }
            }
            .background(Brand.chamber)
            // Renders are sized for the surface showing them. This fires again
            // when the device is folded or opened, and the session re-renders
            // for the new display while keeping the photo and the factor.
            .task(id: proxy.size) {
                let longest = max(proxy.size.width, proxy.size.height) * displayScale
                await model.session.fit(longestEdge: max(1200, Int(longest * 1.25)))
            }
            .animation(.smooth(duration: 0.28), value: isWide)
        }
        .preferredColorScheme(.dark)
        .tint(Brand.coral)
    }

    @ViewBuilder
    private var canvas: some View {
        switch model.mode {
        case .single: PreviewPane(model: model)
        case .batch:  BatchPane(model: model)
        }
    }
}
