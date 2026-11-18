import DesqueezeCore
import SwiftUI

/// What is new in this version, then a tour of the features. The tour can be
/// skipped at any point, and neither shows again once finished or skipped.
struct WelcomeFlow: View {
    let plan: WelcomePlan
    let version: String
    let finish: () -> Void

    @State private var page = 0

    private enum Page: Hashable {
        case whatsNew
        case tour(Int)
    }

    private var pages: [Page] {
        (plan.showsWhatsNew ? [Page.whatsNew] : [])
            + (plan.showsTour ? Self.tour.indices.map(Page.tour) : [])
    }

    private var current: Page { pages[min(page, pages.count - 1)] }
    private var isLast: Bool { page >= pages.count - 1 }
    private var inTour: Bool { if case .tour = current { true } else { false } }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    content(for: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.smooth, value: page)

            footer
        }
        .background(Brand.ground)
        .foregroundStyle(Brand.primary)
        .tint(Brand.accent)
        .interactiveDismissDisabled()
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            SectionLabel(text: inTour ? "TOUR" : "WHAT'S NEW IN \(version)")
            Spacer()
            // The tour is optional from its first step, and from the screen
            // before it.
            if !isLast {
                Button("Skip") { finish() }
                    .font(Brand.sans(15))
                    .foregroundStyle(Brand.secondary)
                    .accessibilityHint("Closes this and the tour")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            if pages.count > 1 {
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Brand.accent : Brand.secondary.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityHidden(true)
            }
            Button {
                if isLast { finish() } else { page += 1 }
            } label: {
                Text(primaryTitle)
                    .font(Brand.sans(16, weight: .medium))
                    .foregroundStyle(Brand.ground)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.glassProminent)
            .tint(Brand.accent)
            .controlSize(.large)
            .frame(maxWidth: 420)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var primaryTitle: String {
        if isLast { return plan.showsTour ? "Start using StillScope" : "Done" }
        if case .whatsNew = current, plan.showsTour { return "Take the tour" }
        return "Next"
    }

    // MARK: - Pages

    @ViewBuilder
    private func content(for page: Page) -> some View {
        switch page {
        case .whatsNew: whatsNew
        case .tour(let index): tourStep(Self.tour[index])
        }
    }

    private var whatsNew: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("StillScope")
                    .font(Brand.sans(34, weight: .medium))
                Text("Correct anamorphic photos, live.")
                    .font(Brand.sans(17))
                    .foregroundStyle(Brand.secondary)
                    .padding(.bottom, 4)
                ForEach(Self.news) { item in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 22))
                            .foregroundStyle(Brand.accent)
                            .frame(width: 34)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title).font(Brand.sans(16, weight: .medium))
                            Text(item.text)
                                .font(Brand.sans(14))
                                .foregroundStyle(Brand.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func tourStep(_ step: Item) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            Image(systemName: step.symbol)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Brand.accent)
                .frame(width: 128, height: 128)
                .glassEffect(.regular, in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: 10) {
                Text(step.title).font(Brand.sans(26, weight: .medium))
                Text(step.text)
                    .font(Brand.sans(16))
                    .foregroundStyle(Brand.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 460)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Words

    struct Item: Identifiable {
        let symbol: String, title: String, text: String
        var id: String { title }
    }

    static let news = [
        Item(symbol: "slider.horizontal.3", title: "Live correction",
             text: "Drag the factor and the preview follows. It snaps to common lens squeezes; hold between two to fine-tune."),
        Item(symbol: "sparkle.magnifyingglass", title: "Finds squeezed photos",
             text: "Switch it on in Settings and StillScope looks through your recent photos, on your device, and offers to queue the ones that need correcting."),
        Item(symbol: "checkmark.circle", title: "Batches your way",
             text: "Correct as many photos as you like. Select which ones, and set one factor for all of them or one for each."),
        Item(symbol: "square.and.arrow.up", title: "Works from other apps",
             text: "Use StillScope from the Share sheet, or edit right inside Photos."),
        Item(symbol: "iphone.gen3", title: "Made for the open Duo",
             text: "Held sideways on an open iPhone Duo, the controls sit at the edge and the factor slider stays on screen."),
    ]

    static let tour = [
        Item(symbol: "photo.on.rectangle.angled", title: "Choose your photos",
             text: "Tap Choose Photos. Pick one to correct and inspect, or several to work through as a batch."),
        Item(symbol: "arrow.left.and.right", title: "Set the squeeze",
             text: "Tap the factor at the bottom to open the slider. Match it to your lens, or drag until the proportions look right. Tap outside to put it away."),
        Item(symbol: "plus.magnifyingglass", title: "Check the detail",
             text: "Tap the photo, or the magnifier, to inspect it at 1:1 with pinch and double-tap zoom."),
        Item(symbol: "checkmark.circle", title: "Choose which to correct",
             text: "In a batch, tap a photo to select or deselect it. The slider changes the selected ones. Tap a photo's own factor to set just that one."),
        Item(symbol: "square.and.arrow.down", title: "Save",
             text: "Tap the save button to add the corrected photos to your library, with their capture details kept. Settings has an optional white matte."),
        Item(symbol: "gearshape", title: "Let it find them for you",
             text: "In Settings, switch on Find squeezed photos. Then the circular arrows rescan, and a long press rechecks everything."),
    ]
}
