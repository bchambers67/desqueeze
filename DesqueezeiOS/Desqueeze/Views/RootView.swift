import SwiftUI

/// Root layout: the photograph fills the screen, and the controls float over
/// it in a single Liquid Glass layer.
///
/// On an open iPhone Duo that layer is a bar down the right side; on every
/// other device it is the system toolbar along the bottom. Folding or opening
/// a Duo moves it between the two while the app runs. Apple publishes no hinge
/// or fold API, so nothing here reads one: `BarEdge` goes by the window's size.
struct RootView: View {
    @Bindable var model: AppModel

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            let edge = BarEdge.resolve(for: proxy.size)

            NavigationStack {
                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // The content layer keeps the brand ground and runs to
                    // every edge, beneath the glass.
                    .background(Brand.chamber.ignoresSafeArea())
                    .safeAreaInset(edge: .trailing, spacing: 0) {
                        if edge == .trailing { SideBar(model: model) }
                    }
                    .overlay(alignment: .top) { StatusChip(model: model) }
                    .toolbar {
                        if edge == .bottom { BottomBarItems(model: model) }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .animation(.smooth(duration: 0.3), value: edge)
                    .animation(.smooth(duration: 0.2), value: model.notice)
            }
            // Renders are sized for the surface showing them. This fires again
            // when the device is folded or opened, and the session re-renders
            // for the new display while keeping the photo and the factor.
            .task(id: proxy.size) {
                let longest = max(proxy.size.width, proxy.size.height) * displayScale
                await model.session.fit(longestEdge: max(1200, Int(longest * 1.25)))
            }
        }
        .preferredColorScheme(.dark)
        .tint(Brand.white)
        .fullScreenCover(isPresented: $model.isInspecting) {
            InspectorView(session: model.session)
        }
        .sheet(item: $model.sharedFile) { file in
            ActivitySheet(url: file.url)
        }
        .sheet(isPresented: $model.isChoosingFactor) {
            FactorSheet(model: model)
        }
    }

    @ViewBuilder
    private var canvas: some View {
        switch model.mode {
        case .single: PreviewPane(model: model)
        case .batch:  BatchPane(model: model)
        }
    }
}
