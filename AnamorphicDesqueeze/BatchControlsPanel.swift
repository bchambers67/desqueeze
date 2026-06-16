import SwiftUI

struct BatchControlsPanel: View {
    @ObservedObject var processor: BatchProcessor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.spacingLG) {
                brandHeader
                divider
                summary
                divider
                applyToAllSection
                divider
                exportSection
                Spacer(minLength: Brand.spacingLG)
            }
            .padding(Brand.spacingLG)
        }
        .background(Brand.backgroundSecondary)
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: Brand.spacingXS) {
            HStack(spacing: Brand.spacingSM) {
                AppIconLogo(size: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("CHAMBERS & LIGHT")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(2.5)
                        .foregroundColor(Brand.accent)
                    Text("Batch")
                        .font(.system(size: 18, weight: .light, design: .serif))
                        .foregroundColor(Brand.textPrimary)
                }
            }
            Text("Multi-image desqueeze")
                .font(Brand.fontCaption)
                .foregroundColor(Brand.textTertiary)
                .padding(.leading, 40)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Brand.spacingMD) {
            sectionLabel("SUMMARY")
            VStack(spacing: Brand.spacingXS) {
                row("Total", value: "\(processor.items.count)")
                row("Auto-detected", value: "\(processor.detectedCount)")
                if processor.completedCount > 0 {
                    row("Saved", value: "\(processor.completedCount)", valueColor: Brand.success)
                }
                if processor.failedCount > 0 {
                    row("Failed", value: "\(processor.failedCount)", valueColor: Brand.danger)
                }
            }
        }
    }

    private var applyToAllSection: some View {
        VStack(alignment: .leading, spacing: Brand.spacingMD) {
            sectionLabel("APPLY TO ALL")

            HStack(spacing: Brand.spacingSM) {
                Picker("", selection: $processor.bulkPreset) {
                    ForEach(SqueezePreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(processor.isExporting)

                if processor.bulkPreset == .custom {
                    TextField("1.33", text: $processor.bulkCustomFactor)
                        .textFieldStyle(.roundedBorder)
                        .font(Brand.fontMono)
                        .frame(width: 56)
                        .disabled(processor.isExporting)
                }
            }

            Button {
                processor.applyBulkFactorToAll()
            } label: {
                HStack(spacing: Brand.spacingXS) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 11))
                    Text("Apply to All Images")
                        .font(Brand.fontCaption)
                }
                .foregroundColor(Brand.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Brand.spacingSM)
                .background(Brand.surface)
                .cornerRadius(Brand.radiusSM)
            }
            .buttonStyle(.plain)
            .disabled(processor.isExporting || processor.items.isEmpty)

            Button {
                processor.resetAllToAutoDetected()
            } label: {
                HStack(spacing: Brand.spacingXS) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("Reset All to Auto-detected")
                        .font(.system(size: 10))
                }
                .foregroundColor(Brand.accent)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(processor.isExporting || processor.detectedCount == 0)
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: Brand.spacingMD) {
            sectionLabel("EXPORT")

            if let err = processor.errorMessage {
                HStack(spacing: Brand.spacingXS) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(Brand.danger)
                    Text(err)
                        .font(Brand.fontCaption)
                        .foregroundColor(Brand.danger)
                }
                .padding(.horizontal, Brand.spacingMD)
                .padding(.vertical, Brand.spacingSM)
                .background(Brand.danger.opacity(0.08))
                .cornerRadius(Brand.radiusSM)
            }

            if processor.isExporting {
                progressBlock
            }

            exportButton

            Button(role: .destructive) {
                processor.clear()
            } label: {
                Text("Clear Batch")
                    .font(Brand.fontCaption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Brand.spacingSM)
            }
            .buttonStyle(.plain)
            .foregroundColor(Brand.textSecondary)
            .disabled(processor.isExporting)

            Text("Saves <original>_desqueezed.<ext> into the chosen folder.")
                .font(.system(size: 10))
                .foregroundColor(Brand.textTertiary)
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: Brand.spacingXS) {
            HStack {
                Text("\(processor.currentExportIndex + 1) / \(processor.items.count)")
                    .font(Brand.fontMono)
                    .foregroundColor(Brand.textSecondary)
                Spacer()
                Button("Cancel") { processor.cancelExport() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Brand.danger)
            }
            ProgressView(
                value: Double(processor.currentExportIndex),
                total: Double(max(processor.items.count, 1))
            )
            .tint(Brand.accent)
        }
    }

    @ViewBuilder
    private var exportButton: some View {
        let label = HStack(spacing: Brand.spacingSM) {
            if processor.isExporting {
                ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
            } else {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 13))
            }
            Text(processor.isExporting ? "Exporting…" : "Export All to Folder…")
                .font(Brand.fontHeading)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Brand.spacingMD)

        if #available(macOS 26.0, *) {
            Button(action: chooseOutputFolderAndExport) { label }
                .buttonStyle(.glassProminent)
                .tint(Brand.accent)
                .controlSize(.large)
                .disabled(processor.isExporting || processor.items.isEmpty)
        } else {
            let canExport = !processor.isExporting && !processor.items.isEmpty
            Button(action: chooseOutputFolderAndExport) {
                label
                    .foregroundColor(canExport ? Brand.backgroundPrimary : Brand.textTertiary)
                    .background(canExport ? Brand.accent : Brand.surface)
                    .cornerRadius(Brand.radiusMD)
            }
            .buttonStyle(.plain)
            .disabled(!canExport)
        }
    }

    private func chooseOutputFolderAndExport() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose a folder to save desqueezed images"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        processor.exportAll(to: folder)
    }

    // MARK: - Helpers

    private var divider: some View {
        Divider().overlay(Brand.border)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(1.8)
            .foregroundColor(Brand.textTertiary)
    }

    private func row(_ label: String, value: String, valueColor: Color = Brand.textSecondary) -> some View {
        HStack {
            Text(label)
                .font(Brand.fontCaption)
                .foregroundColor(Brand.textTertiary)
            Spacer()
            Text(value)
                .font(Brand.fontMono)
                .foregroundColor(valueColor)
        }
    }
}
