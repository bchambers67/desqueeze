import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var processor: DesqueezeProcessor
    @ObservedObject var batch: BatchProcessor
    @State private var isDragOver = false

    private let supportedTypes: [UTType] = [.jpeg, .png, .tiff, .heic, .rawImage, .image]

    var body: some View {
        ZStack {
            dropZoneBackground

            VStack(spacing: Brand.spacingMD) {
                ZStack {
                    Circle()
                        .fill(isDragOver ? Brand.accent.opacity(0.15) : Brand.surfaceElevated)
                        .frame(width: 72, height: 72)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundColor(isDragOver ? Brand.accent : Brand.textTertiary)
                }

                VStack(spacing: Brand.spacingXS) {
                    Text("Drop image(s) here")
                        .font(Brand.fontHeading)
                        .foregroundColor(isDragOver ? Brand.textPrimary : Brand.textSecondary)
                    Text("Drop one for live preview · drop many for batch")
                        .font(Brand.fontCaption)
                        .foregroundColor(Brand.textTertiary)
                }

                Text("JPEG  ·  TIFF  ·  PNG  ·  HEIC  ·  RAW")
                    .font(.system(size: 10, weight: .regular))
                    .tracking(0.5)
                    .foregroundColor(Brand.textTertiary)
                    .padding(.top, Brand.spacingXS)
            }
            .padding(Brand.spacingXL)
        }
        .contentShape(Rectangle())
        .onTapGesture { openFilePicker() }
        .onDrop(of: supportedTypes.map(\.identifier), isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
    }

    @ViewBuilder
    private var dropZoneBackground: some View {
        let border = RoundedRectangle(cornerRadius: Brand.radiusLG)
            .strokeBorder(
                isDragOver ? Brand.accent : Brand.border,
                style: StrokeStyle(
                    lineWidth: isDragOver ? 1.5 : 1,
                    dash: isDragOver ? [] : [6, 4]
                )
            )

        if #available(macOS 26.0, *) {
            ZStack {
                RoundedRectangle(cornerRadius: Brand.radiusLG)
                    .fill(.clear)
                    .glassEffect(
                        isDragOver ? .regular.tint(Brand.accent).interactive() : .regular.interactive(),
                        in: .rect(cornerRadius: Brand.radiusLG)
                    )
                border
            }
            .animation(.easeInOut(duration: 0.15), value: isDragOver)
        } else {
            RoundedRectangle(cornerRadius: Brand.radiusLG)
                .fill(isDragOver ? Brand.accent.opacity(0.07) : Brand.surface)
                .overlay(border)
                .animation(.easeInOut(duration: 0.15), value: isDragOver)
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = supportedTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        if urls.count == 1, let url = urls.first {
            processor.loadImage(from: url)
        } else if urls.count > 1 {
            batch.add(urls: urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        if providers.count > 1 {
            return handleBatchDrop(providers: providers)
        }
        guard let provider = providers.first else { return false }

        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { obj, _ in
                if let image = obj as? NSImage {
                    DispatchQueue.main.async { processor.loadImage(image) }
                }
            }
            return true
        }

        for type in supportedTypes {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                    if let url = url {
                        // Copy to temp because the sandbox copy may disappear
                        let tmp = FileManager.default.temporaryDirectory
                            .appendingPathComponent(url.lastPathComponent)
                        try? FileManager.default.copyItem(at: url, to: tmp)
                        DispatchQueue.main.async { processor.loadImage(from: tmp) }
                    }
                }
                return true
            }
        }
        return false
    }

    private func handleBatchDrop(providers: [NSItemProvider]) -> Bool {
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
            batch.add(urls: collected)
        }
        return true
    }
}
