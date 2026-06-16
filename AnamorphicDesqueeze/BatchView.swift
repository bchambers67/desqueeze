import SwiftUI
import UniformTypeIdentifiers

struct BatchView: View {
    @ObservedObject var processor: BatchProcessor
    @State private var isDragOver = false

    private let supportedTypes: [UTType] = [.jpeg, .png, .tiff, .heic, .rawImage, .image]

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            list
        }
        .background(Brand.backgroundPrimary)
        .overlay(dragOverlay)
        .onDrop(of: supportedTypes.map(\.identifier), isTargeted: $isDragOver) { providers in
            handleAdditionalDrop(providers: providers)
        }
    }

    private var header: some View {
        HStack(spacing: Brand.spacingSM) {
            Text("\(processor.items.count) IMAGE\(processor.items.count == 1 ? "" : "S")")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.8)
                .foregroundColor(Brand.textTertiary)

            if processor.detectedCount > 0 {
                Text("·")
                    .foregroundColor(Brand.textTertiary)
                Text("\(processor.detectedCount) auto-detected")
                    .font(Brand.fontCaption)
                    .foregroundColor(Brand.textTertiary)
            }

            Spacer()

            Text("Drag more files here to add")
                .font(.system(size: 10))
                .foregroundColor(Brand.textTertiary)
        }
        .padding(.horizontal, Brand.spacingLG)
        .padding(.vertical, Brand.spacingMD)
    }

    private var divider: some View {
        Divider().overlay(Brand.border)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Brand.spacingSM) {
                ForEach(processor.items) { item in
                    BatchItemRow(item: item, processor: processor)
                }
            }
            .padding(Brand.spacingLG)
        }
    }

    @ViewBuilder
    private var dragOverlay: some View {
        if isDragOver {
            RoundedRectangle(cornerRadius: Brand.radiusLG)
                .strokeBorder(Brand.accent, lineWidth: 2)
                .background(Brand.accent.opacity(0.06))
                .padding(Brand.spacingMD)
                .allowsHitTesting(false)
        }
    }

    private func handleAdditionalDrop(providers: [NSItemProvider]) -> Bool {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let group = DispatchGroup()
        var collected: [URL] = []
        let lock = NSLock()

        for provider in providers {
            for type in supportedTypes {
                guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { continue }
                group.enter()
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                    defer { group.leave() }
                    guard let url = url else { return }
                    let dest = dir.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: dest)
                    lock.lock()
                    collected.append(dest)
                    lock.unlock()
                }
                break
            }
        }
        group.notify(queue: .main) {
            processor.add(urls: collected)
        }
        return true
    }
}

private struct BatchItemRow: View {
    @ObservedObject var item: BatchItem
    @ObservedObject var processor: BatchProcessor

    var body: some View {
        HStack(spacing: Brand.spacingMD) {
            thumbnail
            details
            Spacer(minLength: Brand.spacingSM)
            factorControls
            statusIndicator
            removeButton
        }
        .padding(Brand.spacingSM)
        .background(Brand.surface.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.radiusMD)
                .strokeBorder(Brand.border, lineWidth: 1)
        )
        .cornerRadius(Brand.radiusMD)
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Brand.radiusSM)
                .fill(Brand.backgroundSecondary)
                .frame(width: 60, height: 40)
            if let thumb = item.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSM))
            } else if !item.detectionDone {
                ProgressView().scaleEffect(0.5)
            } else {
                Image(systemName: "photo")
                    .foregroundColor(Brand.textTertiary)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.displayName)
                .font(Brand.fontBody)
                .foregroundColor(Brand.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            detectionLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var detectionLabel: some View {
        if !item.detectionDone {
            Text("Analyzing…")
                .font(.system(size: 10))
                .foregroundColor(Brand.textTertiary)
        } else if let detected = item.detectedFactor {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .foregroundColor(Brand.accent)
                Text(String(format: "Auto: %.2f×", detected))
                    .font(.system(size: 10))
                    .foregroundColor(item.isOverridden ? Brand.textTertiary : Brand.accent)
                if item.isOverridden {
                    Text("·")
                        .foregroundColor(Brand.textTertiary)
                    Button("Reset") { item.resetToAutoDetected() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Brand.accent)
                }
            }
        } else {
            Text("No recommendation — set factor manually")
                .font(.system(size: 10))
                .foregroundColor(Brand.textTertiary)
        }
    }

    private var factorControls: some View {
        HStack(spacing: Brand.spacingXS) {
            Picker("", selection: $item.selectedPreset) {
                ForEach(SqueezePreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 90)
            .disabled(processor.isExporting)

            if item.selectedPreset == .custom {
                TextField("1.33", text: $item.customFactor)
                    .textFieldStyle(.roundedBorder)
                    .font(Brand.fontMono)
                    .frame(width: 52)
                    .disabled(processor.isExporting)
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch item.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(Brand.textTertiary)
                .frame(width: 18)
        case .processing:
            ProgressView().scaleEffect(0.5).frame(width: 18)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Brand.success)
                .frame(width: 18)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Brand.danger)
                .frame(width: 18)
                .help(item.errorMessage ?? "Failed")
        }
    }

    private var removeButton: some View {
        Button {
            processor.remove(item)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(Brand.textTertiary)
        }
        .buttonStyle(.plain)
        .disabled(processor.isExporting)
    }
}
