import DesqueezeCore
import PhotosUI
import SwiftUI

/// The image surface: empty state, live preview, and the frame-edge readout.
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
                Image(decorative: frame.image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(Brand.spacingMD)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Inspect the corrected photo")
            .overlay(alignment: .topTrailing) {
                if session.isRendering {
                    ProgressView().tint(Brand.coral).padding(Brand.spacingLG)
                }
            }

            HStack(alignment: .bottom) {
                readout
                Spacer()
                FrameMark(text: "TAP TO INSPECT", size: 9)
                    .padding(.horizontal, Brand.spacingSM)
                    .padding(.vertical, 5)
                    .background(Brand.chamber.opacity(0.85))
            }
            .padding(Brand.spacingMD)
        }
    }

    /// Dimensions and ratio, set as a frame-edge annotation.
    @ViewBuilder
    private var readout: some View {
        if let out = session.outputSize, let source = session.sourceSize {
            HStack(spacing: Brand.spacingSM) {
                CoralRule(width: 10)
                FrameMark(text: "\(source.width) × \(source.height) → \(out.width) × \(out.height)")
                FrameMark(text: String(format: "· %.2f:1", session.squeeze.aspectRatio(for: source)))
            }
            .padding(.horizontal, Brand.spacingSM)
            .padding(.vertical, 5)
            .background(Brand.chamber.opacity(0.85))
        }
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
