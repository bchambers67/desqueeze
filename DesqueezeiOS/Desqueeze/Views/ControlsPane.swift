import DesqueezeCore
import PhotosUI
import SwiftUI

/// Factor selection, readout, and output, for one photo or a batch.
struct ControlsPane: View {
    let model: AppModel

    @State private var picked: [PhotosPickerItem] = []
    @State private var typed = ""
    @State private var isWorking = false
    @State private var shared: SharedFile?
    @FocusState private var customFocused: Bool

    private var session: Session { model.session }
    private var isBatch: Bool { model.mode == .batch }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.spacingLG) {
                masthead
                Hairline()
                factors
                if !isBatch {
                    Hairline()
                    output
                }
                Hairline()
                actions
                colophon
            }
            .padding(Brand.spacingLG)
        }
        .background(Brand.chamberRaised)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { typed = session.typedFactor }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await model.take(items)
                picked = []
            }
        }
        .sheet(item: $shared) { file in
            ActivitySheet(url: file.url)
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
            SectionLabel(text: isBatch ? "BATCH FACTOR" : "SQUEEZE FACTOR")

            if !isBatch, let suggestion = model.suggestion {
                suggestionBanner(suggestion)
            }

            VStack(spacing: 1) {
                ForEach(SqueezePreset.selectable) { preset in
                    row(preset)
                }
                customRow
            }
        }
    }

    /// A factor read from the faces in the photo. Offered, never applied.
    private func suggestionBanner(_ factor: Double) -> some View {
        HStack(spacing: Brand.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                FrameMark(text: "READ FROM FACES", size: 9)
                Text(String(format: "%.2f×", factor))
                    .font(Brand.mono(15, weight: .medium))
                    .foregroundStyle(Brand.white)
            }
            Spacer()
            Button {
                Task { await model.useSuggestion() }
            } label: {
                Text("USE")
                    .font(Brand.sans(11, weight: .medium))
                    .tracking(Brand.tracking(Brand.trackLabel, at: 11))
                    .foregroundStyle(Brand.white)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .overlay(Rectangle().stroke(Brand.coral, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(Brand.spacingMD)
        .overlay(Rectangle().stroke(Brand.hairline, lineWidth: 1))
    }

    private func row(_ preset: SqueezePreset) -> some View {
        let active = session.preset == preset
        return Button {
            customFocused = false
            Task { await session.choose(preset) }
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
                Rectangle().fill(active ? Brand.coral : .clear).frame(width: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var customRow: some View {
        let active = session.preset == .custom
        let invalid = active && !session.typedFactorIsValid
        return HStack(spacing: Brand.spacingSM) {
            Button {
                customFocused = true
                Task { await session.type(typed) }
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

            TextField("1.33", text: $typed)
                .focused($customFocused)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(Brand.mono(15))
                .foregroundStyle(Brand.white)
                .frame(width: 70)
                .padding(.vertical, 6)
                .background(Brand.chamber)
                .overlay(
                    // A factor that cannot be read is flagged in the error
                    // red, not coral: coral is the accent, not a warning.
                    Rectangle().stroke(invalid ? Brand.error : active ? Brand.coral : Brand.hairline, lineWidth: 1)
                )
                .onChange(of: typed) { _, text in
                    Task { await session.type(text) }
                }

            Text("×")
                .font(Brand.sans(13))
                .foregroundStyle(Brand.silver)
        }
        .padding(.horizontal, Brand.spacingMD)
        .padding(.vertical, 13)
        .background(active ? Brand.chamber : .clear)
        .overlay(alignment: .leading) {
            Rectangle().fill(active ? Brand.coral : .clear).frame(width: 2)
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
                metric("SOURCE", session.sourceSize.map(dimensions) ?? "—")
                metric("OUTPUT", session.outputSize.map(dimensions) ?? "—")
                metric("FACTOR", String(format: "%.2f×", session.squeeze.factor))
                metric("ASPECT", session.sourceSize.map {
                    String(format: "%.2f : 1", session.squeeze.aspectRatio(for: $0))
                } ?? "—")
            }
        }
    }

    private func dimensions(_ size: PixelSize) -> String { "\(size.width) × \(size.height)" }

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

            if let notice = model.notice {
                HStack(alignment: .top, spacing: Brand.spacingSM) {
                    Rectangle().fill(notice.isError ? Brand.error : Brand.silver).frame(width: 2)
                    Text(notice.text)
                        .font(Brand.sans(12))
                        .foregroundStyle(notice.isError ? Brand.error : Brand.silver)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isBatch {
                primary("SAVE ALL TO LIBRARY", enabled: !model.batch.items.isEmpty) {
                    await model.runBatch()
                }
            } else {
                primary("SAVE TO LIBRARY", enabled: session.hasPhoto) {
                    await model.saveToLibrary()
                }
                secondary("SHARE…", enabled: session.hasPhoto) {
                    if let url = await model.exportedFile() { shared = SharedFile(url: url) }
                }
            }

            HStack(spacing: Brand.spacingLG) {
                PhotosPicker(selection: $picked, maxSelectionCount: AppModel.batchLimit, matching: .images) {
                    Text("Choose photos…")
                        .font(Brand.sans(13))
                        .foregroundStyle(Brand.silver)
                }
                .buttonStyle(.plain)

                if session.hasPhoto || isBatch {
                    Button("Clear") { model.reset() }
                        .font(Brand.sans(13))
                        .foregroundStyle(Brand.silver)
                        .buttonStyle(.plain)
                }
            }
            .disabled(isWorking)
        }
    }

    private func primary(_ title: String, enabled: Bool, action: @escaping () async -> Void) -> some View {
        let live = enabled && !isWorking
        return Button {
            run(action)
        } label: {
            Text(isWorking ? "WORKING" : title)
                .font(Brand.sans(12, weight: .medium))
                .tracking(Brand.tracking(Brand.trackLabel, at: 12))
                .foregroundStyle(live ? Brand.white : Brand.silver.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Brand.spacingMD)
                .background(live ? Brand.coral : Brand.chamber)
        }
        .buttonStyle(.plain)
        .disabled(!live)
    }

    private func secondary(_ title: String, enabled: Bool, action: @escaping () async -> Void) -> some View {
        let live = enabled && !isWorking
        return Button {
            run(action)
        } label: {
            Text(title)
                .font(Brand.sans(12, weight: .medium))
                .tracking(Brand.tracking(Brand.trackLabel, at: 12))
                .foregroundStyle(live ? Brand.white : Brand.silver.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .overlay(Rectangle().stroke(Brand.silver.opacity(live ? 1 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!live)
    }

    private func run(_ action: @escaping () async -> Void) {
        isWorking = true
        Task {
            await action()
            isWorking = false
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

// MARK: - Share sheet

private struct SharedFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// The system share sheet. `ShareLink` wants its item up front; the export is
/// rendered on demand, so the sheet is presented once the file exists.
private struct ActivitySheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
