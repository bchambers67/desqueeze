import SwiftUI

struct ControlsPanel: View {
    @ObservedObject var processor: DesqueezeProcessor
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.spacingLG) {
                brandHeader
                divider
                squeezeFactor
                divider
                outputInfo
                divider
                exportSection
                Spacer(minLength: Brand.spacingLG)
            }
            .padding(Brand.spacingLG)
        }
        .background(Brand.backgroundSecondary)
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: Brand.spacingXS) {
            HStack(spacing: Brand.spacingSM) {
                AppIconLogo(size: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("CHAMBERS & LIGHT")
                        .font(Brand.grotesk(8, weight: .semibold))
                        .tracking(2.5)
                        .foregroundColor(Brand.accent)
                    Text("Desqueeze")
                        .font(Brand.display(18))
                        .foregroundColor(Brand.textPrimary)
                }
            }
            Text("Anamorphic image correction")
                .font(Brand.fontCaption)
                .foregroundColor(Brand.textTertiary)
                .padding(.leading, 40)
        }
    }

    // MARK: - Squeeze Factor

    private var squeezeFactor: some View {
        VStack(alignment: .leading, spacing: Brand.spacingMD) {
            sectionLabel("SQUEEZE FACTOR")

            suggestionBanner

            VStack(spacing: 2) {
                ForEach(SqueezePreset.allCases.filter { $0 != .custom }) { preset in
                    presetRow(preset)
                }
                customRow
            }
        }
    }

    @ViewBuilder
    private var suggestionBanner: some View {
        if processor.isEstimating {
            HStack(spacing: Brand.spacingSM) {
                ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                Text("Analyzing image…")
                    .font(Brand.fontCaption)
                    .foregroundColor(Brand.textTertiary)
                Spacer()
            }
            .padding(.horizontal, Brand.spacingMD)
            .padding(.vertical, Brand.spacingSM)
            .background(Brand.surface.opacity(0.5))
            .cornerRadius(Brand.radiusSM)
        } else if processor.sourceImage != nil, processor.suggestedFactor == nil {
            HStack(spacing: Brand.spacingSM) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 11))
                    .foregroundColor(Brand.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("NO RECOMMENDATION")
                        .font(Brand.grotesk(8, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(Brand.textTertiary)
                    Text("Couldn't detect a face — pick a factor manually.")
                        .font(Brand.fontCaption)
                        .foregroundColor(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, Brand.spacingMD)
            .padding(.vertical, Brand.spacingSM)
            .background(Brand.surface.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.radiusSM)
                    .strokeBorder(Brand.border, lineWidth: 1)
            )
            .cornerRadius(Brand.radiusSM)
        } else if let factor = processor.suggestedFactor {
            HStack(spacing: Brand.spacingSM) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundColor(Brand.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("RECOMMENDED")
                        .font(Brand.grotesk(8, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(Brand.accent)
                    Text(String(format: "%.2f×  •  from face geometry", factor))
                        .font(Brand.fontCaption)
                        .foregroundColor(Brand.textSecondary)
                }
                Spacer()
                Button("Use") {
                    processor.applySuggestion()
                }
                .buttonStyle(.plain)
                .font(Brand.grotesk(11, weight: .semibold))
                .foregroundColor(Brand.accent)
                .padding(.horizontal, Brand.spacingSM)
                .padding(.vertical, 4)
                .background(Brand.accent.opacity(0.15))
                .cornerRadius(Brand.radiusSM)
            }
            .padding(.horizontal, Brand.spacingMD)
            .padding(.vertical, Brand.spacingSM)
            .background(Brand.accent.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.radiusSM)
                    .strokeBorder(Brand.accent.opacity(0.25), lineWidth: 1)
            )
            .cornerRadius(Brand.radiusSM)
        }
    }

    private func presetRow(_ preset: SqueezePreset) -> some View {
        Button {
            processor.selectedPreset = preset
            processor.process()
        } label: {
            HStack(spacing: Brand.spacingSM) {
                radio(on: processor.selectedPreset == preset)
                Text(preset.rawValue)
                    .font(Brand.fontBody)
                    .foregroundColor(processor.selectedPreset == preset ? Brand.textPrimary : Brand.textSecondary)
                Spacer()
                if processor.suggestedPreset == preset {
                    recommendedBadge
                }
            }
            .padding(.horizontal, Brand.spacingMD)
            .padding(.vertical, 10)
            .liquidGlassRow(isSelected: processor.selectedPreset == preset, cornerRadius: Brand.radiusMD)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var customRow: some View {
        HStack(spacing: Brand.spacingSM) {
            Button {
                processor.selectedPreset = .custom
                processor.process()
            } label: {
                HStack(spacing: Brand.spacingSM) {
                    radio(on: processor.selectedPreset == .custom)
                    Text("Custom")
                        .font(Brand.fontBody)
                        .foregroundColor(processor.selectedPreset == .custom ? Brand.textPrimary : Brand.textSecondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField("1.33", text: $processor.customFactor)
                .textFieldStyle(.plain)
                .font(Brand.fontMono)
                .foregroundColor(Brand.textPrimary)
                .multilineTextAlignment(.center)
                .frame(width: 52)
                .padding(.horizontal, Brand.spacingSM)
                .padding(.vertical, 5)
                .background(Brand.surface)
                .cornerRadius(Brand.radiusSM)
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.radiusSM)
                        .strokeBorder(
                            processor.selectedPreset == .custom ? Brand.accent.opacity(0.5) : Brand.border,
                            lineWidth: 1
                        )
                )
                .disabled(processor.selectedPreset != .custom)
                .onSubmit {
                    processor.selectedPreset = .custom
                    processor.process()
                }

            Text("×")
                .font(Brand.fontCaption)
                .foregroundColor(Brand.textTertiary)

            if processor.suggestedPreset == .custom {
                recommendedBadge
            }
        }
        .padding(.horizontal, Brand.spacingMD)
        .padding(.vertical, 10)
        .liquidGlassRow(isSelected: processor.selectedPreset == .custom, cornerRadius: Brand.radiusMD)
    }

    private var recommendedBadge: some View {
        Text("RECOMMENDED")
            .font(Brand.grotesk(8, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(Brand.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Brand.accent.opacity(0.15))
            .cornerRadius(4)
    }

    private func radio(on: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(on ? Brand.accent : Brand.border, lineWidth: 1.5)
                .frame(width: 16, height: 16)
            if on {
                Circle().fill(Brand.accent).frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Output Info

    private var outputInfo: some View {
        VStack(alignment: .leading, spacing: Brand.spacingMD) {
            sectionLabel("OUTPUT")
            VStack(spacing: Brand.spacingXS) {
                infoRow("Source",  value: sizeString(processor.sourceImage))
                infoRow("Output",  value: sizeString(processor.processedImage))
                infoRow("Factor",  value: String(format: "%.2f×", processor.activeFactor))
                if let src = processor.sourceImage {
                    infoRow("Aspect", value: aspectString(src, factor: processor.activeFactor))
                }
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Brand.fontCaption)
                .foregroundColor(Brand.textTertiary)
            Spacer()
            Text(value)
                .font(Brand.fontMono)
                .foregroundColor(Brand.textSecondary)
        }
    }

    private func sizeString(_ img: NSImage?) -> String {
        guard let img else { return "—" }
        return "\(Int(img.size.width)) × \(Int(img.size.height))"
    }

    private func aspectString(_ img: NSImage, factor: CGFloat) -> String {
        let ratio = (img.size.width * factor) / img.size.height
        return String(format: "%.2f : 1", ratio)
    }

    // MARK: - Export

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: Brand.spacingMD) {
            sectionLabel(processor.isRoundTrip ? "EDIT IN" : "EXPORT")

            roundTripBanner

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

            if showSuccess {
                HStack(spacing: Brand.spacingXS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Brand.success)
                    Text(processor.isRoundTrip
                         ? "Saved — return to Lightroom"
                         : "Image saved successfully")
                        .font(Brand.fontCaption)
                        .foregroundColor(Brand.success)
                }
                .transition(.opacity)
            }

            let canExport = processor.processedImage != nil && !processor.isProcessing

            exportButton(canExport: canExport)
                .disabled(!canExport)
                .animation(.easeInOut(duration: 0.2), value: canExport)

            if processor.isRoundTrip {
                Button("Export to a different file…") { export() }
                    .buttonStyle(.plain)
                    .font(Brand.grotesk(11))
                    .foregroundColor(Brand.textTertiary)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Saves as JPEG, PNG, or TIFF based on the chosen file extension.")
                    .font(Brand.grotesk(10))
                    .foregroundColor(Brand.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var roundTripBanner: some View {
        if let url = processor.roundTripURL {
            HStack(spacing: Brand.spacingSM) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(Brand.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("OPENED FROM HOST")
                        .font(Brand.grotesk(8, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(Brand.accent)
                    Text(url.lastPathComponent)
                        .font(Brand.fontCaption)
                        .foregroundColor(Brand.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(.horizontal, Brand.spacingMD)
            .padding(.vertical, Brand.spacingSM)
            .background(Brand.accent.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.radiusSM)
                    .strokeBorder(Brand.accent.opacity(0.25), lineWidth: 1)
            )
            .cornerRadius(Brand.radiusSM)
        }
    }

    @ViewBuilder
    private func exportButton(canExport: Bool) -> some View {
        let label = HStack(spacing: Brand.spacingSM) {
            if processor.isProcessing {
                ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
            } else {
                Image(systemName: exportIconName)
                    .font(.system(size: 13))
            }
            Text(exportButtonTitle)
                .font(Brand.fontHeading)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Brand.spacingMD)

        let action: () -> Void = processor.isRoundTrip ? saveBack : export

        if #available(macOS 26.0, *) {
            Button(action: action) { label }
                .buttonStyle(.glassProminent)
                .tint(Brand.accent)
                .controlSize(.large)
        } else {
            Button(action: action) {
                label
                    .foregroundColor(canExport ? Brand.backgroundPrimary : Brand.textTertiary)
                    .background(canExport ? Brand.accent : Brand.surface)
                    .cornerRadius(Brand.radiusMD)
            }
            .buttonStyle(.plain)
        }
    }

    private var exportButtonTitle: String {
        if processor.isProcessing { return "Processing…" }
        return processor.isRoundTrip ? "Return Desqueezed Image to Lightroom" : "Export De-squeezed"
    }

    private var exportIconName: String {
        processor.isRoundTrip ? "arrow.triangle.2.circlepath" : "square.and.arrow.down"
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg, .png, .tiff]
        panel.nameFieldStringValue = processor.suggestedExportName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            if await processor.exportImage(to: url) {
                withAnimation { showSuccess = true }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation { showSuccess = false }
            }
        }
    }

    private func saveBack() {
        Task {
            if await processor.saveBackToHost() {
                withAnimation { showSuccess = true }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation { showSuccess = false }
            }
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Divider().overlay(Brand.border)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Brand.grotesk(9, weight: .semibold))
            .tracking(1.8)
            .foregroundColor(Brand.textTertiary)
    }
}

private extension View {
    @ViewBuilder
    func liquidGlassRow(isSelected: Bool, cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            if isSelected {
                self.glassEffect(
                    .regular.tint(Brand.accent).interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
            } else {
                self
            }
        } else {
            self
                .background(isSelected ? Brand.accent.opacity(0.07) : Color.clear)
                .cornerRadius(cornerRadius)
        }
    }
}
