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
            ItemFactorSheet(name: item.name, current: item.squeeze) { squeeze in
                batch.setSqueeze(squeeze, for: item.id)
                editing = nil
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
    /// button opens a sheet of tiles; there is no menu to scroll.
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

/// One photo's factor: follow the batch, or take a preset of its own.
private struct ItemFactorSheet: View {
    let name: String
    let current: Squeeze?
    let choose: (Squeeze?) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(spacing: 18) {
            Text(name)
                .font(Brand.mono(13))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            tile("Follow batch", selected: current == nil) { choose(nil) }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(SqueezePreset.selectable) { preset in
                    if let factor = preset.factor {
                        tile(preset.label, selected: current?.factor == factor) {
                            choose(Squeeze(factor: factor))
                        }
                    }
                }
            }
        }
        .controlSize(.large)
        .padding(20)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func tile(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        let label = Text(title)
            .font(Brand.mono(16, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 36)
        if selected {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .tint(Brand.coral)
                .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: action) { label }
                .buttonStyle(.bordered)
        }
    }
}
