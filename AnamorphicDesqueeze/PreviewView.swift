import SwiftUI

enum PreviewMode: String, CaseIterable {
    case sideBySide = "Side by Side"
    case original   = "Original"
    case processed  = "De-squeezed"
}

struct PreviewView: View {
    @ObservedObject var processor: DesqueezeProcessor
    @State private var mode: PreviewMode = .sideBySide

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Brand.border)
            GeometryReader { geo in
                switch mode {
                case .sideBySide: sideBySide(geo: geo)
                case .original:   singleCell(image: processor.sourceImage,   label: "ORIGINAL")
                case .processed:  singleCell(image: processor.processedImage, label: "DE-SQUEEZED")
                }
            }
        }
        .background(Brand.backgroundPrimary)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: Brand.spacingXS) {
            ForEach(PreviewMode.allCases, id: \.self) { m in
                Button { mode = m } label: {
                    Text(m.rawValue)
                        .font(Brand.fontCaption)
                        .foregroundColor(mode == m ? Brand.accent : Brand.textSecondary)
                        .padding(.horizontal, Brand.spacingSM)
                        .padding(.vertical, Brand.spacingXS)
                        .background(mode == m ? Brand.accent.opacity(0.12) : Color.clear)
                        .cornerRadius(Brand.radiusSM)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let img = processor.processedImage {
                Text("\(Int(img.size.width)) × \(Int(img.size.height)) px")
                    .font(Brand.fontMono)
                    .foregroundColor(Brand.textTertiary)
            }
        }
        .padding(.horizontal, Brand.spacingMD)
        .padding(.vertical, Brand.spacingSM)
        .background(Brand.backgroundSecondary)
    }

    // MARK: - Layouts

    @ViewBuilder
    private func sideBySide(geo: GeometryProxy) -> some View {
        HStack(spacing: 1) {
            singleCell(image: processor.sourceImage,    label: "ORIGINAL")
            Rectangle().fill(Brand.border).frame(width: 1)
            singleCell(image: processor.processedImage, label: "DE-SQUEEZED")
        }
    }

    @ViewBuilder
    private func singleCell(image: NSImage?, label: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Brand.backgroundPrimary)
            } else {
                Rectangle()
                    .fill(Brand.backgroundSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        Group {
                            if processor.isProcessing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.7)
                                    .tint(Brand.accent)
                            } else {
                                Text("—")
                                    .font(Brand.fontCaption)
                                    .foregroundColor(Brand.textTertiary)
                            }
                        }
                    )
            }

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Brand.textSecondary)
                .padding(.horizontal, Brand.spacingSM)
                .padding(.vertical, 3)
                .background(Brand.backgroundPrimary.opacity(0.80))
                .cornerRadius(Brand.radiusSM)
                .padding(Brand.spacingSM)
        }
    }
}
