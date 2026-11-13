import DesqueezeCore
import SwiftUI

/// The batch, as pictures: every queued photo, corrected as it will be saved.
///
/// Each tile is the photo's thumbnail given the shape of its factor. Moving
/// the slider reshapes all of them at once; nothing is re-rendered to do it.
/// A photo follows the batch factor unless a tap gives it one of its own.
struct BatchPane: View {
    let model: AppModel

    private var batch: Batch { model.batch }

    @State private var editing: Batch.Item?

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 420), spacing: Brand.spacingMD)]
    private let tileHeight: CGFloat = 150

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Brand.spacingMD) {
                ForEach(batch.items) { item in
                    tile(item)
                }
            }
            .padding(Brand.spacingMD)
        }
        .background(Brand.chamber)
        .sheet(item: $editing) { item in
            ItemFactorSheet(name: item.name, current: item.squeeze,
                            batchFactor: model.session.squeeze.factor) { squeeze in
                batch.setSqueeze(squeeze, for: item.id)
            }
        }
    }

    private func tile(_ item: Batch.Item) -> some View {
        let factor = (item.squeeze ?? model.session.squeeze).factor
        let locked = batch.isRunning || item.state == .done

        return VStack(spacing: 6) {
            Button {
                editing = item
            } label: {
                ZStack {
                    if let frame = model.thumbnails[item.id] {
                        let shot = CGFloat(frame.image.width) / CGFloat(max(frame.image.height, 1))
                        Image(decorative: frame.image, scale: 1)
                            .resizable()
                            .aspectRatio(shot * factor, contentMode: .fit)
                            .opacity(item.state == .done ? 0.55 : 1)
                    } else {
                        ProgressView().tint(Brand.coral)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: tileHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .accessibilityLabel("\(item.name), \(String(format: "%.2f", factor)) times")
            .accessibilityHint("Sets this photo's own factor")
            .overlay(alignment: .topLeading) { stateMark(item.state).padding(8) }
            .overlay(alignment: .topTrailing) {
                Button {
                    batch.remove(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Brand.white)
                        .frame(width: 44, height: 44)
                }
                .disabled(batch.isRunning)
                .accessibilityLabel("Remove \(item.name)")
            }
            .overlay(alignment: .bottomTrailing) {
                // Only a photo with its own factor is marked; the rest follow
                // the slider and need no label.
                if let own = item.squeeze {
                    Text(String(format: "%.2f×", own.factor))
                        .font(Brand.mono(11))
                        .foregroundStyle(Brand.white)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(Brand.chamber.opacity(0.85))
                        .overlay(Rectangle().stroke(Brand.coral, lineWidth: 1))
                        .padding(8)
                }
            }

            if case .failed(let reason) = item.state {
                Text(reason)
                    .font(Brand.sans(11))
                    .foregroundStyle(Brand.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func stateMark(_ state: Batch.Item.State) -> some View {
        switch state {
        case .waiting:
            EmptyView()
        case .working:
            ProgressView().controlSize(.small).tint(Brand.coral)
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Brand.white)
                .accessibilityLabel("Saved")
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Brand.error)
                .accessibilityLabel("Failed")
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

            SheetDoneButton { dismiss() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .ignoresSafeArea(.container, edges: .horizontal)
        .onChange(of: factor) { _, new in choose(Squeeze(factor: new)) }
        .fittedSheet()
        .presentationDragIndicator(.visible)
    }
}
