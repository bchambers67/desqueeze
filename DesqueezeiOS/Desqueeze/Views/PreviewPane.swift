import SwiftUI
import PhotosUI

/// The image surface: empty state, live preview, and the frame-edge readout.
struct PreviewPane: View {
    @Bindable var model: EditorModel
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Brand.chamber

            if let image = model.preview {
                loaded(image)
            } else if model.hasImage {
                // Source is in, first render still running.
                ProgressView()
                    .tint(Brand.coral)
            } else {
                emptyState
            }
        }
        .clipped()
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.load(data: data)
                }
            }
        }
    }

    // MARK: - Loaded

    private func loaded(_ image: UIImage) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Brand.spacingMD)
                .overlay(alignment: .topTrailing) {
                    if model.isWorking {
                        ProgressView()
                            .tint(Brand.coral)
                            .padding(Brand.spacingLG)
                    }
                }

            readout
                .padding(Brand.spacingMD)
        }
    }

    /// Dimensions and ratio, set as a frame-edge annotation.
    @ViewBuilder
    private var readout: some View {
        if let out = model.outputPixelSize {
            HStack(spacing: Brand.spacingSM) {
                CoralRule(width: 10)
                FrameMark(text: "\(Int(out.width)) × \(Int(out.height))")
                if let ratio = model.aspectRatio {
                    FrameMark(text: String(format: "· %.2f:1", ratio))
                }
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
                Rectangle()
                    .stroke(Brand.silver, lineWidth: 1)
                    .frame(width: 24, height: 50)
                Rectangle()
                    .fill(Brand.coral)
                    .frame(width: 20, height: 2)
                Rectangle()
                    .stroke(Brand.silver, lineWidth: 1)
                    .frame(width: 68, height: 50)
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                VStack(spacing: Brand.spacingXS) {
                    Text("CHOOSE A PHOTO")
                        .font(Brand.sans(12, weight: .medium))
                        .tracking(Brand.tracking(Brand.trackLabel, at: 12))
                        .foregroundStyle(Brand.white)
                    Text("Anamorphic frames, corrected.")
                        .font(Brand.sans(13))
                        .foregroundStyle(Brand.silver)
                }
                .padding(.horizontal, Brand.spacingLG)
                .padding(.vertical, Brand.spacingMD)
                .overlay(Rectangle().stroke(Brand.silver, lineWidth: 1))
            }
            .buttonStyle(.plain)

            FrameMark(text: "HEIC · RAW · JPEG · TIFF · PNG", size: 9)
        }
        .padding(Brand.spacingXL)
    }
}
