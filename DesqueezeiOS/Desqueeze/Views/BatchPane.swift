import DesqueezeCore
import SwiftUI

/// The batch: every queued photo, its factor, and how it fared.
struct BatchPane: View {
    let model: AppModel

    private var batch: Batch { model.batch }

    @State private var editing: Batch.Item?

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
        .sheet(item: $editing) { item in
            ItemFactorSheet(name: item.name, current: item.squeeze,
                            batchFactor: model.session.squeeze.factor) { squeeze in
                batch.setSqueeze(squeeze, for: item.id)
            }
        }
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
                    .frame(width: 44, height: 44)
            }
            .disabled(batch.isRunning)
            .accessibilityLabel("Remove \(item.name)")
        }
        .padding(.horizontal, Brand.spacingMD)
        .padding(.vertical, 12)
    }

    /// Each photo follows the batch unless given a factor of its own. The
    /// button opens the factor slider; there is no menu to scroll.
    private func factorMenu(_ item: Batch.Item) -> some View {
        Button {
            editing = item
        } label: {
            Text(item.squeeze.map { String(format: "%.2f×", $0.factor) } ?? "BATCH")
                .font(Brand.mono(13))
                .foregroundStyle(item.squeeze == nil ? Brand.silver : Brand.white)
                .padding(.horizontal, 12)
                .frame(minWidth: 72, minHeight: 44)
                .overlay(Rectangle().stroke(item.squeeze == nil ? Brand.hairline : Brand.coral, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Factor for \(item.name)")
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

/// One photo's factor: its own, on the slider, or back to following the batch.
private struct ItemFactorSheet: View {
    let name: String
    let follows: Bool
    let choose: (Squeeze?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var factor: Double

    init(name: String, current: Squeeze?, batchFactor: Double, choose: @escaping (Squeeze?) -> Void) {
        self.name = name
        self.follows = current == nil
        self.choose = choose
        _factor = State(initialValue: FactorSlider.clamped(current?.factor ?? batchFactor))
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(name)
                    .font(Brand.mono(13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Follow batch") {
                    choose(nil)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .disabled(follows)
            }

            FactorSlider(factor: $factor)
        }
        .padding(20)
        .onChange(of: factor) { _, new in choose(Squeeze(factor: new)) }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }
}
