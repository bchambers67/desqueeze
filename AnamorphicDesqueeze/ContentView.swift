import SwiftUI
import UniformTypeIdentifiers

/// Root layout: the photograph fills the window, and the controls frame it in
/// the system's Liquid Glass.
///
/// The primary actions live in the window toolbar, where the system supplies
/// the material and the grouping. The detail — suggestion, readouts, round-trip
/// state, batch tallies — lives in a trailing inspector, which is the platform's
/// own panel for exactly that and can be put away to give the image the window.
struct ContentView: View {
    @StateObject private var processor = DesqueezeProcessor()
    @StateObject private var batch = BatchProcessor()
    @EnvironmentObject private var externalEdit: ExternalEditState

    @State private var showsInspector = true
    @State private var isEnteringCustom = false
    @State private var customDraft = ""

    private var isBatchMode: Bool { !batch.isEmpty }
    private var hasContent: Bool { processor.sourceImage != nil || isBatchMode }

    var body: some View {
        canvas
            .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
            // The content layer keeps the brand ground, edge to edge.
            .background(Brand.backgroundPrimary.ignoresSafeArea())
            .inspector(isPresented: $showsInspector) {
                Group {
                    if isBatchMode {
                        BatchControlsPanel(processor: batch)
                    } else {
                        ControlsPanel(processor: processor)
                    }
                }
                .inspectorColumnWidth(min: 240, ideal: 280, max: 340)
            }
            .frame(minWidth: 800, idealWidth: 1600, minHeight: 600, idealHeight: 940)
            .preferredColorScheme(.dark)
            .toolbar { toolbar }
            .alert("Custom factor", isPresented: $isEnteringCustom) {
                TextField("1.33", text: $customDraft)
                Button("Cancel", role: .cancel) {}
                Button("Use") { useCustom(customDraft) }
            } message: {
                Text("Between 1.00 and 3.00.")
            }
            .onAppear { consumePendingExternalEdit() }
            .onChange(of: externalEdit.pendingURL) {
                consumePendingExternalEdit()
            }
    }

    @ViewBuilder
    private var canvas: some View {
        if isBatchMode {
            BatchView(processor: batch)
        } else if processor.sourceImage != nil {
            PreviewView(processor: processor)
        } else {
            DropZoneView(processor: processor, batch: batch)
                .padding(Brand.spacingLG)
        }
    }

    // MARK: - Toolbar

    /// Grouped by what they act on: the queue, the correction, the result.
    /// Icon items share a background; the factor is text, so it sits alone.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button(action: open) {
                Label("Open…", systemImage: "photo.on.rectangle.angled")
            }
            .keyboardShortcut("o")
            .help("Open one photo, or several for a batch")

            Button(role: .destructive) {
                processor.clearImage()
                batch.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(!hasContent || batch.isExporting)
            .help("Clear and start over")
        }

        ToolbarSpacer(.fixed)

        ToolbarItem {
            factorMenu
        }

        ToolbarSpacer(.flexible)

        ToolbarItem(placement: .primaryAction) {
            // The one tinted control: exporting is what the app is for.
            Button(action: export) {
                Label(exportTitle, systemImage: processor.isRoundTrip && !isBatchMode
                      ? "arrow.triangle.2.circlepath" : "square.and.arrow.down")
            }
            .buttonStyle(.glassProminent)
            .tint(Brand.coral)
            // The accent is pale, so the label on it is the dark ground.
            .foregroundStyle(Brand.backgroundPrimary)
            .keyboardShortcut("e")
            .disabled(!canExport)
            .help(exportTitle)
        }

        ToolbarSpacer(.fixed)

        ToolbarItem(placement: .primaryAction) {
            Button {
                showsInspector.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .help(showsInspector ? "Hide the inspector" : "Show the inspector")
        }
    }

    /// The squeeze factor: the current value as the label, the glass as the menu.
    private var factorMenu: some View {
        Menu {
            if !isBatchMode, let suggestion = processor.suggestedFactor {
                Section("Read from faces") {
                    Button {
                        processor.applySuggestion()
                    } label: {
                        Label(String(format: "Use %.2f×", Double(suggestion)), systemImage: "face.dashed")
                    }
                }
            }
            Section(isBatchMode ? "Apply to all" : "Squeeze factor") {
                ForEach(SqueezePreset.allCases.filter { $0 != .custom }) { preset in
                    Toggle(preset.rawValue, isOn: Binding(
                        get: { currentPreset == preset },
                        set: { _ in choose(preset) }
                    ))
                }
            }
            Section {
                Button {
                    customDraft = isBatchMode ? batch.bulkCustomFactor : processor.customFactor
                    isEnteringCustom = true
                } label: {
                    Label("Custom…", systemImage: "number")
                }
            }
        } label: {
            Text(factorLabel)
                .font(Brand.mono(13, weight: .medium))
                .monospacedDigit()
        }
        .help("Squeeze factor")
        .accessibilityLabel("Squeeze factor")
        .accessibilityValue(factorLabel)
        .disabled(batch.isExporting)
    }

    private var currentPreset: SqueezePreset {
        isBatchMode ? batch.bulkPreset : processor.selectedPreset
    }

    private var factorLabel: String {
        if isBatchMode {
            return batch.bulkPreset == .custom ? "\(batch.bulkCustomFactor)×" : batch.bulkPreset.rawValue
        }
        return String(format: "%.2f×", Double(processor.activeFactor))
    }

    private func choose(_ preset: SqueezePreset) {
        if isBatchMode {
            batch.bulkPreset = preset
            batch.applyBulkFactorToAll()
        } else {
            processor.selectedPreset = preset
            processor.process()
        }
    }

    private func useCustom(_ text: String) {
        // Accept a comma decimal, and hold the value to what glass can do.
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite else { return }
        let factor = String(format: "%.2f", min(max(value, 1.0), 3.0))
        if isBatchMode {
            batch.bulkCustomFactor = factor
            batch.bulkPreset = .custom
            batch.applyBulkFactorToAll()
        } else {
            processor.customFactor = factor
            processor.selectedPreset = .custom
            processor.process()
        }
    }

    // MARK: - Actions

    private var exportTitle: String {
        if isBatchMode { return "Export All…" }
        return processor.isRoundTrip ? "Save Back" : "Export…"
    }

    private var canExport: Bool {
        isBatchMode
            ? !batch.isExporting
            : processor.processedImage != nil && !processor.isProcessing
    }

    private func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        if urls.count == 1, let url = urls.first {
            batch.clear()
            processor.loadImage(from: url)
        } else if urls.count > 1 {
            processor.clearImage()
            batch.add(urls: urls)
        }
    }

    private func export() {
        if isBatchMode {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.message = "Choose a folder to save desqueezed images"
            guard panel.runModal() == .OK, let folder = panel.url else { return }
            batch.exportAll(to: folder)
        } else if processor.isRoundTrip {
            Task { _ = await processor.saveBackToHost() }
        } else {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.jpeg, .png, .tiff]
            panel.nameFieldStringValue = processor.suggestedExportName
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return }
            Task { _ = await processor.exportImage(to: url) }
        }
    }

    private func consumePendingExternalEdit() {
        guard let url = externalEdit.pendingURL else { return }
        batch.clear()
        processor.loadForRoundTrip(from: url)
        externalEdit.pendingURL = nil
    }
}
