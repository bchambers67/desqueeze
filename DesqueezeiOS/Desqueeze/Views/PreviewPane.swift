import DesqueezeCore
import PhotosUI
import SwiftUI

/// The image surface: the empty state and the live preview.
struct PreviewPane: View {
    let model: AppModel

    @State private var picked: [PhotosPickerItem] = []

    private var session: Session { model.session }

    var body: some View {
        ZStack {
            Brand.chamber

            if let frame = session.preview {
                loaded(frame)
            } else if session.isRendering {
                ProgressView().tint(Brand.coral)
            } else {
                emptyState
            }
        }
        .clipped()
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await model.take(items)
                picked = []
            }
        }
    }

    // MARK: - Loaded

    private func loaded(_ frame: CoreImageRenderer.Frame) -> some View {
        ZStack(alignment: .bottomLeading) {
            Button {
                model.isInspecting = true
            } label: {
                // Shaped by the factor in use now, not the one this frame was
                // rendered at: the picture follows the slider at once, and the
                // proper render replaces it a moment later.
                Image(decorative: frame.image, scale: 1)
                    .resizable()
                    .aspectRatio(liveAspect(of: frame), contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(Brand.spacingMD)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Inspect the corrected photo")

            HStack(alignment: .bottom) {
                Spacer()
                FrameMark(text: "TAP TO INSPECT", size: 9)
                    .padding(.horizontal, Brand.spacingSM)
                    .padding(.vertical, 5)
                    .background(Brand.chamber.opacity(0.85))
            }
            .padding(Brand.spacingMD)
        }
    }

    private func liveAspect(of frame: CoreImageRenderer.Frame) -> CGFloat {
        if let out = session.outputSize, out.height > 0 {
            return CGFloat(out.width) / CGFloat(out.height)
        }
        return CGFloat(frame.image.width) / CGFloat(max(frame.image.height, 1))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Brand.spacingLG) {
            // The mark: a squeezed frame opening to its true width.
            HStack(spacing: Brand.spacingSM) {
                Rectangle().stroke(Brand.silver, lineWidth: 1).frame(width: 24, height: 50)
                Rectangle().fill(Brand.coral).frame(width: 20, height: 2)
                Rectangle().stroke(Brand.silver, lineWidth: 1).frame(width: 68, height: 50)
            }

            PhotosPicker(selection: $picked, maxSelectionCount: AppModel.batchLimit, matching: .images) {
                VStack(spacing: Brand.spacingXS) {
                    Text("CHOOSE PHOTOS")
                        .font(Brand.sans(12, weight: .medium))
                        .tracking(Brand.tracking(Brand.trackLabel, at: 12))
                        .foregroundStyle(Brand.white)
                    Text("One to correct and inspect. Several for a batch.")
                        .font(Brand.sans(13))
                        .foregroundStyle(Brand.silver)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Brand.spacingLG)
                .padding(.vertical, Brand.spacingMD)
                .overlay(Rectangle().stroke(Brand.silver, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if let failure = session.failure {
                Text(failure)
                    .font(Brand.sans(12))
                    .foregroundStyle(Brand.error)
            }

            FrameMark(text: "HEIC · RAW · JPEG · TIFF · PNG", size: 9)
        }
        .padding(Brand.spacingXL)
    }
}
