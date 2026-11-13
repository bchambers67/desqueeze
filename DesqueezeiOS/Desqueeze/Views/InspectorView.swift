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
        VStack(spacing: 0) {
            bar
            Hairline()
            ZStack {
                Color.black
                if let frame {
                    ZoomableImage(image: frame.image, displayScale: displayScale,
                                  command: $command, zoomPercent: $zoomPercent)
                } else if let failure {
                    Text(failure).font(Brand.sans(13)).foregroundStyle(Brand.error)
                } else {
                    ProgressView().tint(Brand.coral)
                }
            }
        }
        .background(Brand.chamber)
        .preferredColorScheme(.dark)
        .task {
            do { frame = try await session.inspectionFrame() }
            catch { failure = error.localizedDescription }
        }
    }

    private var bar: some View {
        HStack(spacing: Brand.spacingMD) {
            if let frame {
                FrameMark(text: "\(frame.image.width) × \(frame.image.height)")
            }
            Spacer()
            FrameMark(text: "\(zoomPercent)%")
            barButton("FIT") { command = .fit }
            barButton("1:1") { command = .actualPixels }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Brand.white)
                    .frame(width: 34, height: 30)
                    .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Brand.spacingMD)
        .padding(.vertical, Brand.spacingSM)
    }

    private func barButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Brand.mono(11))
                .tracking(Brand.tracking(Brand.trackLabel, at: 11))
                .foregroundStyle(Brand.white)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

enum ZoomCommand { case fit, actualPixels }

/// A pinch-zoomable image in which a zoom scale of 1 means one image pixel per
/// display pixel.
private struct ZoomableImage: UIViewRepresentable {
    let image: CGImage
    let displayScale: CGFloat
    @Binding var command: ZoomCommand?
    @Binding var zoomPercent: Int

    func makeCoordinator() -> Coordinator { Coordinator(zoomPercent: $zoomPercent) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.backgroundColor = .black
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

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.layoutIfNeeded(scroll)
        if let command {
            switch command {
            case .fit:          scroll.setZoomScale(scroll.minimumZoomScale, animated: true)
            case .actualPixels: scroll.setZoomScale(1, animated: true)
            }
            DispatchQueue.main.async { self.command = nil }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        private var zoomPercent: Binding<Int>
        private var laidOutFor: CGSize = .zero

        init(zoomPercent: Binding<Int>) { self.zoomPercent = zoomPercent }

        /// Sets the zoom limits for the scroll view's current size, and starts
        /// at fit. Runs again when the size changes, as on a fold or rotation.
        func layoutIfNeeded(_ scroll: UIScrollView) {
            scroll.layoutIfNeeded()
            guard let imageView, scroll.bounds.size != laidOutFor,
                  scroll.bounds.width > 0, imageView.bounds.width > 0 else { return }
            laidOutFor = scroll.bounds.size

            let fit = min(scroll.bounds.width / imageView.bounds.width,
                          scroll.bounds.height / imageView.bounds.height)
            // The floor is fit or 1:1, whichever is smaller, so 1:1 is always
            // reachable even for a photo smaller than the screen.
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
                scroll.setZoomScale(scroll.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let size = CGSize(width: scroll.bounds.width, height: scroll.bounds.height)
                scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                       width: size.width, height: size.height), animated: true)
            }
        }
    }
}
