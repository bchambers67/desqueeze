import DesqueezeCore
import SwiftUI

/// The batch, as pictures: every queued photo, corrected as it will be saved.
///
/// Each tile is the photo's thumbnail given the shape of its factor. Moving
/// the slider reshapes all of them at once; nothing is re-rendered to do it.
/// The slider changes the photos that are selected, all of them to begin with;
/// a tap on a tile selects or deselects it, and a tap on its factor opens a
/// slider for that photo alone.
struct BatchPane: View {
    let model: AppModel

    private var batch: Batch { model.batch }

    @State private var editing: Batch.Item?

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 420), spacing: Brand.spacingMD)]
    private let tileHeight: CGFloat = 150

    var body: some View {
        ScrollView {
            selectionBar
            LazyVGrid(columns: columns, spacing: Brand.spacingMD) {
                ForEach(batch.items) { item in
                    tile(item)
                }
            }
            .padding(.horizontal, Brand.spacingMD)
            .padding(.bottom, Brand.spacingMD)
        }
        .background(Brand.ground)
        .sheet(item: $editing) { item in
            ItemFactorSheet(name: item.name, current: item.squeeze,
                            batchFactor: model.session.squeeze.factor) { squeeze in
                batch.setSqueeze(squeeze, for: item.id)
            }
        }
    }

    /// How many are selected, and a way to take in all or none.
    private var selectionBar: some View {
        HStack(spacing: Brand.spacingMD) {
            Text("\(batch.selectedCount) of \(batch.items.count) selected")
                .font(Brand.mono(12))
                .foregroundStyle(Brand.secondary)
            Spacer()
            Button("Select all") { model.selectAll(true) }
                .disabled(batch.selectedCount == batch.items.count)
            Button("None") { model.selectAll(false) }
                .disabled(batch.selectedCount == 0)
        }
        .font(Brand.sans(13))
        .tint(Brand.accent)
        .padding(.horizontal, Brand.spacingMD)
        .padding(.top, Brand.spacingMD)
        .disabled(batch.isRunning)
    }

    private func tile(_ item: Batch.Item) -> some View {
        let factor = (item.squeeze ?? model.session.squeeze).factor
        let locked = batch.isRunning || item.state == .done

        return VStack(spacing: 6) {
            Button {
                model.toggleSelected(item.id)
            } label: {
                ZStack {
                    if let frame = model.thumbnails[item.id] {
                        let shot = CGFloat(frame.image.width) / CGFloat(max(frame.image.height, 1))
                        Image(decorative: frame.image, scale: 1)
                            .resizable()
                            .aspectRatio(shot * factor, contentMode: .fit)
                            .opacity(item.state == .done ? 0.55 : item.isSelected ? 1 : 0.35)
                    } else {
                        ProgressView().tint(Brand.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: tileHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .accessibilityLabel("\(item.name), \(String(format: "%.2f", factor)) times")
            .accessibilityAddTraits(item.isSelected ? .isSelected : [])
            .accessibilityHint("Selects or deselects this photo")
            .overlay(alignment: .topLeading) { stateMark(item).padding(8) }
            .overlay(alignment: .topTrailing) {
                Button {
                    model.removeFromBatch(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Brand.primary)
                        .frame(width: 44, height: 44)
                }
                .disabled(batch.isRunning)
                .accessibilityLabel("Remove \(item.name)")
            }
            .overlay(alignment: .bottomTrailing) {
                // Every photo shows its factor. A tap opens it for this photo
                // alone.
                Button {
                    editing = item
                } label: {
                    Text(String(format: "%.2f×", factor))
                        .font(Brand.mono(11))
                        .foregroundStyle(Brand.primary)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(Brand.ground.opacity(0.85))
                        .overlay(Rectangle().stroke(item.squeeze == nil ? Brand.secondary : Brand.accent, lineWidth: 1))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .accessibilityLabel("Set the factor for \(item.name)")
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
    private func stateMark(_ item: Batch.Item) -> some View {
        switch item.state {
        case .waiting:
            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(item.isSelected ? Brand.accent : Brand.secondary)
                .accessibilityHidden(true)
        case .working:
            ProgressView().controlSize(.small).tint(Brand.accent)
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Brand.primary)
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
