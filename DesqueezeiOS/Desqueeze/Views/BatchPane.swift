import DesqueezeCore
import SwiftUI

/// The batch: every queued photo, its factor, and how it fared.
struct BatchPane: View {
    let model: AppModel

    private var batch: Batch { model.batch }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionLabel(text: "\(batch.items.count) PHOTOS")
                Spacer()
                FrameMark(text: "\(batch.finishedCount) / \(batch.items.count) SAVED")
            }
            .padding(Brand.spacingMD)

            Hairline()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(batch.items) { item in
                        row(item)
                        Hairline()
                    }
                }
            }
        }
        .background(Brand.chamber)
    }

    private func row(_ item: Batch.Item) -> some View {
        HStack(spacing: Brand.spacingMD) {
            stateMark(item.state)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(Brand.mono(13))
                    .foregroundStyle(Brand.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if case .failed(let reason) = item.state {
                    Text(reason)
                        .font(Brand.sans(11))
                        .foregroundStyle(Brand.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Brand.spacingSM)

            factorMenu(item)

            Button {
                batch.remove(item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Brand.silver)
                    .frame(width: 28, height: 28)
            }
            .disabled(batch.isRunning)
            .accessibilityLabel("Remove \(item.name)")
        }
        .padding(.horizontal, Brand.spacingMD)
        .padding(.vertical, 12)
    }

    /// Each photo follows the batch unless given a factor of its own.
    private func factorMenu(_ item: Batch.Item) -> some View {
        Menu {
            Button("Follow batch") { batch.setSqueeze(nil, for: item.id) }
            Divider()
            ForEach(SqueezePreset.selectable) { preset in
                Button(preset.label) {
                    if let factor = preset.factor {
                        batch.setSqueeze(Squeeze(factor: factor), for: item.id)
                    }
                }
            }
        } label: {
            Text(item.squeeze.map { String(format: "%.2f×", $0.factor) } ?? "BATCH")
                .font(Brand.mono(12))
                .foregroundStyle(item.squeeze == nil ? Brand.silver : Brand.white)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .overlay(Rectangle().stroke(item.squeeze == nil ? Brand.hairline : Brand.coral, lineWidth: 1))
        }
        .disabled(batch.isRunning || item.state == .done)
    }

    @ViewBuilder
    private func stateMark(_ state: Batch.Item.State) -> some View {
        switch state {
        case .waiting:
            Rectangle().stroke(Brand.silver.opacity(0.5), lineWidth: 1).frame(width: 10, height: 10)
        case .working:
            ProgressView().controlSize(.mini).tint(Brand.coral).frame(width: 10, height: 10)
        case .done:
            Rectangle().fill(Brand.silver).frame(width: 10, height: 10)
        case .failed:
            Rectangle().fill(Brand.error).frame(width: 10, height: 10)
        }
    }
}
