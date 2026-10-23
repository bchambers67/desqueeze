import SwiftUI
import PhotosUI

/// Factor selection, readout, and export.
struct ControlsPane: View {
    @Bindable var model: EditorModel

    @State private var pickerItem: PhotosPickerItem?
    @State private var exportState: ExportState = .idle
    @FocusState private var customFocused: Bool

    private enum ExportState: Equatable {
        case idle, working, saved
        case failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.spacingLG) {
                masthead
                Hairline()
                factors
                Hairline()
                output
                Hairline()
                actions
                colophon
            }
            .padding(Brand.spacingLG)
        }
        .background(Brand.chamberRaised)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.load(data: data)
                    exportState = .idle
                }
            }
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(alignment: .leading, spacing: Brand.spacingSM) {
            CoralRule()
            Wordmark(size: 9)
            Text("Desqueeze")
                .font(Brand.sans(30, weight: .light))
                .tracking(Brand.tracking(0.02, at: 30))
                .foregroundStyle(Brand.white)
        }
    }

    // MARK: - Factors

    private var factors: some View {
        VStack(alignment: .leading, spacing: Brand.spacingMD) {
            SectionLabel(text: "SQUEEZE FACTOR")

            VStack(spacing: 1) {
                ForEach(SqueezePreset.selectable) { preset in
                    row(preset)
                }
                customRow
            }
        }
    }

    private func row(_ preset: SqueezePreset) -> some View {
        let active = model.preset == preset
        return Button {
            customFocused = false
            model.preset = preset
        } label: {
            HStack(spacing: Brand.spacingSM) {
                marker(active)
                Text(preset.label)
                    .font(Brand.mono(15, weight: active ? .medium : .regular))
                    .foregroundStyle(active ? Brand.white : Brand.silver)
                Spacer()
                FrameMark(text: preset.hint, size: 9)
            }
            .padding(.horizontal, Brand.spacingMD)
            .padding(.vertical, 13)
            .background(active ? Brand.chamber : .clear)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(active ? Brand.coral : .clear)
                    .frame(width: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var customRow: some View {
        let active = model.preset == .custom
        return HStack(spacing: Brand.spacingSM) {
            Button {
                model.preset = .custom
                customFocused = true
            } label: {
                HStack(spacing: Brand.spacingSM) {
                    marker(active)
                    Text("Custom")
                        .font(Brand.sans(15))
                        .foregroundStyle(active ? Brand.white : Brand.silver)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField("1.33", text: $model.customFactor)
                .focused($customFocused)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(Brand.mono(15))
                .foregroundStyle(Brand.white)
                .frame(width: 70)
                .padding(.vertical, 6)
                .background(Brand.chamber)
                .overlay(
                    Rectangle().stroke(active ? Brand.coral : Brand.hairline, lineWidth: 1)
                )
                .disabled(!active)

            Text("×")
                .font(Brand.sans(13))
                .foregroundStyle(Brand.silver)
        }
        .padding(.horizontal, Brand.spacingMD)
        .padding(.vertical, 13)
        .background(active ? Brand.chamber : .clear)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(active ? Brand.coral : .clear)
                .frame(width: 2)
        }
    }

    /// Selection marker. Square, like everything else in the system.
    private func marker(_ on: Bool) -> some View {
        Rectangle()
            .stroke(on ? Brand.coral : Brand.silver.opacity(0.5), lineWidth: 1)
            .frame(width: 12, height: 12)
            .overlay {
                if on { Rectangle().fill(Brand.coral).frame(width: 6, height: 6) }
            }
    }

    // MARK: - Output

    private var output: some View {
        VStack(alignment: .leading, spacing: Brand.spacingMD) {
            SectionLabel(text: "OUTPUT")
            VStack(spacing: Brand.spacingSM) {
                metric("SOURCE", model.sourcePixelSize.map(dimensions) ?? "—")
                metric("OUTPUT", model.outputPixelSize.map(dimensions) ?? "—")
                metric("FACTOR", String(format: "%.2f×", model.factor))
                metric("ASPECT", model.aspectRatio.map { String(format: "%.2f : 1", $0) } ?? "—")
            }
        }
    }

    private func dimensions(_ size: CGSize) -> String {
        "\(Int(size.width)) × \(Int(size.height))"
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Brand.sans(10))
                .tracking(Brand.tracking(Brand.trackMeta, at: 10))
                .foregroundStyle(Brand.silver.opacity(0.7))
            Spacer()
            Text(value)
                .font(Brand.mono(13))
                .foregroundStyle(Brand.white)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(alignment: .leading, spacing: Brand.spacingMD) {
            SectionLabel(text: "EXPORT")

            if let message = model.errorMessage {
                notice(message, tone: Brand.error)
            }

            switch exportState {
            case .failed(let message): notice(message, tone: Brand.error)
            case .saved:               notice("Saved to your library.", tone: Brand.silver)
            default:                   EmptyView()
            }

            Button(action: export) {
                Text(exportState == .working ? "SAVING" : "SAVE TO LIBRARY")
                    .font(Brand.sans(12, weight: .medium))
                    .tracking(Brand.tracking(Brand.trackLabel, at: 12))
                    .foregroundStyle(model.hasImage ? Brand.white : Brand.silver.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Brand.spacingMD)
                    .background(model.hasImage ? Brand.coral : Brand.chamber)
            }
            .buttonStyle(.plain)
            .disabled(!model.hasImage || exportState == .working)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Choose a different photo…")
                    .font(Brand.sans(13))
                    .foregroundStyle(Brand.silver)
            }
            .buttonStyle(.plain)
        }
    }

    private func notice(_ text: String, tone: Color) -> some View {
        HStack(alignment: .top, spacing: Brand.spacingSM) {
            Rectangle().fill(tone).frame(width: 2)
            Text(text)
                .font(Brand.sans(12))
                .foregroundStyle(tone)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func export() {
        exportState = .working
        Task {
            do {
                let data = try await model.exportJPEG()
                try await PhotoLibraryWriter.save(jpeg: data)
                exportState = .saved
                try? await Task.sleep(for: .seconds(3))
                if exportState == .saved { exportState = .idle }
            } catch {
                exportState = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Colophon

    private var colophon: some View {
        VStack(alignment: .leading, spacing: Brand.spacingSM) {
            Hairline()
            FrameMark(text: "CHAMBERS & LIGHT LLC · BROOKLYN NY", size: 9)
        }
        .padding(.top, Brand.spacingMD)
    }
}
