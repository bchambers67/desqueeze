import SwiftUI
import UIKit

/// Full-screen inspection of the corrected photo.
///
/// Shows a frame rendered for inspection, not the screen-sized preview, so at
/// 1:1 each image pixel sits on one display pixel and what you see is what the
/// resampler produced. Zoom and pan are a `UIScrollView`'s own: pinch,
/// double-tap and momentum behave as they do everywhere else on the system.
struct InspectorView: View {
    let session: Session

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    @State private var frame: CoreImageRenderer.Frame?
    @State private var failure: String?
    @State private var command: ZoomCommand?
    @State private var zoomPercent = 100

    var body: some View {
        ZStack {
            Brand.ground.ignoresSafeArea()
            if let frame {
                ZoomableImage(image: frame.image, displayScale: displayScale,
                              command: $command, zoomPercent: $zoomPercent)
                    .ignoresSafeArea()
            } else if let failure {
                Text(failure).font(Brand.sans(13)).foregroundStyle(Brand.error)
            } else {
                ProgressView().tint(Brand.accent)
            }
        }
        // The controls float over the photograph in one glass layer.
        .overlay(alignment: .top) { bar }
        .preferredColorScheme(.dark)
        .tint(Brand.primary)
        .task {
            do { frame = try await session.inspectionFrame() }
            catch { failure = error.localizedDescription }
        }
    }

    /// Every control is the same height and the buttons are the same circle,
    /// whatever they hold, so the row sits on one line. The system's glass
    /// button style sizes each button to its label, which left an icon, a
    /// figure and a cross at three different sizes.
    private static let controlSize: CGFloat = 48

    private var bar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Text("\(zoomPercent)%")
                    .font(Brand.mono(13, weight: .medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(minWidth: 44)
                    .padding(.horizontal, 14)
                    .frame(height: Self.controlSize)
                    .glassEffect(.regular, in: .capsule)
                    .accessibilityLabel("Zoom \(zoomPercent) percent")

                Spacer(minLength: 0)

                control("Fit to screen") { command = .fit } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 16, weight: .medium))
                }
                control("Actual pixels") { command = .actualPixels } label: {
                    Text("1:1").font(Brand.sans(15, weight: .medium))
                }
                control("Close") { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .foregroundStyle(Brand.primary)
            .padding(.horizontal, Brand.spacingMD)
            .padding(.top, Brand.spacingSM)
        }
    }

    private func control<Label: View>(_ name: String, action: @escaping () -> Void,
                                      @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .frame(width: Self.controlSize, height: Self.controlSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(name)
    }
}

enum ZoomCommand { case fit, actualPixels }

/// A scroll view that reports each layout pass, so zoom limits can follow its
/// real size.
final class FittingScrollView: UIScrollView {
    var onLayout: ((FittingScrollView) -> Void)?
    private var lastSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastSize else { return }
        lastSize = bounds.size
        onLayout?(self)
    }
}

/// A pinch-zoomable image in which a zoom scale of 1 means one image pixel per
/// display pixel.
private struct ZoomableImage: UIViewRepresentable {
    let image: CGImage
    let displayScale: CGFloat
    @Binding var command: ZoomCommand?
    @Binding var zoomPercent: Int

    func makeCoordinator() -> Coordinator { Coordinator(zoomPercent: $zoomPercent) }

    func makeUIView(context: Context) -> FittingScrollView {
        let scroll = FittingScrollView()
        scroll.delegate = context.coordinator
        scroll.backgroundColor = UIColor(Brand.ground)
        // Limits depend on the view's size, which is not known until layout,
        // and changes again on a fold or rotation.
        scroll.onLayout = { [coordinator = context.coordinator] in coordinator.layoutIfNeeded($0) }
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.bouncesZoom = true

        // Giving the UIImage the display's scale makes its point size equal to
        // pixels ÷ scale, which is what makes zoomScale 1 mean exactly 1:1.
        let view = UIImageView(image: UIImage(cgImage: image, scale: displayScale, orientation: .up))
        // Past 1:1 the question is what the resampler did; smoothing the
        // display would hide the answer.
        view.layer.magnificationFilter = .nearest
        scroll.addSubview(view)
        scroll.contentSize = view.bounds.size
        context.coordinator.imageView = view

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ scroll: FittingScrollView, context: Context) {
        if let command {
            let target: CGFloat = switch command {
            case .fit:          context.coordinator.fitScale
            case .actualPixels: 1
            }
            // A spring, not the scroll view's own linear zoom: it eases in and
            // settles, and the re-centring animates along with it.
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.86,
                           initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                scroll.zoomScale = target
            }
            DispatchQueue.main.async { self.command = nil }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        private var zoomPercent: Binding<Int>
        private var laidOutFor: CGSize = .zero
        private(set) var fitScale: CGFloat = 1

        init(zoomPercent: Binding<Int>) { self.zoomPercent = zoomPercent }

        /// Sets the zoom limits for the scroll view's current size, and starts
        /// at fit. Runs again when the size changes, as on a fold or rotation.
        func layoutIfNeeded(_ scroll: UIScrollView) {
            guard let imageView, scroll.bounds.size != laidOutFor,
                  scroll.bounds.width > 0, imageView.bounds.width > 0 else { return }
            laidOutFor = scroll.bounds.size

            let fit = min(scroll.bounds.width / imageView.bounds.width,
                          scroll.bounds.height / imageView.bounds.height)
            // The floor is fit or 1:1, whichever is smaller, so 1:1 is always
            // reachable even for a photo smaller than the screen.
            fitScale = fit
            scroll.minimumZoomScale = min(fit, 1)
            scroll.maximumZoomScale = max(6, fit * 8)
            scroll.zoomScale = fit
            centre(scroll)
            report(scroll)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centre(scrollView)
            report(scrollView)
        }

        /// Keeps the image centred while it is smaller than the screen.
        private func centre(_ scroll: UIScrollView) {
            let dx = max(0, (scroll.bounds.width - scroll.contentSize.width) / 2)
            let dy = max(0, (scroll.bounds.height - scroll.contentSize.height) / 2)
            scroll.contentInset = UIEdgeInsets(top: dy, left: dx, bottom: dy, right: dx)
        }

        private func report(_ scroll: UIScrollView) {
            let percent = Int((scroll.zoomScale * 100).rounded())
            if zoomPercent.wrappedValue != percent {
                DispatchQueue.main.async { self.zoomPercent.wrappedValue = percent }
            }
        }

        /// Fit ↔ 1:1, zooming in on the point that was tapped.
        @objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? UIScrollView, let imageView else { return }
            if abs(scroll.zoomScale - 1) < 0.01 {
                scroll.setZoomScale(fitScale, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let size = CGSize(width: scroll.bounds.width, height: scroll.bounds.height)
                scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                       width: size.width, height: size.height), animated: true)
            }
        }
    }
}
