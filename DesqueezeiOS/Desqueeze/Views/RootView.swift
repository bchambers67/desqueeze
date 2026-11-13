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
            let bar = SideBar.metrics(trailingInset: proxy.safeAreaInsets.trailing)
            let panelShown = model.showsFactorPanel(besideSideBar: edge == .trailing)

            NavigationStack {
                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // The factor panel sits between the photograph and the
                    // bar, growing out of the button that opens it: bottom
                    // centre on the bottom bar, the trailing edge beside the
                    // side bar.
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if panelShown {
                            FactorPanel(model: model)
                                .transition(.zoom(from: edge == .trailing ? .trailing : .bottom))
                        }
                    }
                    // The content layer keeps the brand ground and runs to
                    // every edge, beneath the glass.
                    .padding(.trailing, edge == .trailing ? bar.width : 0)
                    .background(Brand.ground.ignoresSafeArea())
                    // An open Duo keeps its clock and status icons in a strip
                    // down the trailing edge. The bar belongs against that
                    // edge, so it runs into the strip and starts below them.
                    .overlay(alignment: .trailing) {
                        if edge == .trailing {
                            SideBar(model: model, panelShown: panelShown, topClearance: bar.topClearance,
                                    width: bar.width, centreShift: bar.centreShift)
                        }
                    }
                    .ignoresSafeArea(.container, edges: edge == .trailing ? .trailing : [])
                    .overlay(alignment: .top) { StatusChip(model: model) }
                    .toolbar {
                        if edge == .bottom { BottomBarItems(model: model, panelShown: panelShown) }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .animation(.smooth(duration: 0.3), value: edge)
                    // A spring with a little give, like a folder opening.
                    .animation(.spring(response: 0.42, dampingFraction: 0.8), value: panelShown)
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
        .tint(Brand.primary)
        .fullScreenCover(isPresented: $model.isInspecting) {
            InspectorView(session: model.session)
        }
        .sheet(item: $model.sharedFile) { file in
            ActivitySheet(url: file.url)
        }
        .sheet(isPresented: $model.isShowingSettings) {
            SettingsSheet(model: model)
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
