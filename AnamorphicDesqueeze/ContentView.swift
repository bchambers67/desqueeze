import SwiftUI

struct ContentView: View {
    @StateObject private var processor = DesqueezeProcessor()
    @StateObject private var batch = BatchProcessor()
    @EnvironmentObject private var externalEdit: ExternalEditState

    private var isBatchMode: Bool { !batch.isEmpty }

    var body: some View {
        HSplitView {
            // ── Left: drop zone / preview / batch list ───────────────────
            ZStack {
                Brand.backgroundPrimary.ignoresSafeArea()

                if isBatchMode {
                    BatchView(processor: batch)
                } else if processor.sourceImage != nil {
                    PreviewView(processor: processor)
                } else {
                    DropZoneView(processor: processor, batch: batch)
                        .padding(Brand.spacingLG)
                }
            }
            .frame(minWidth: 520)

            // ── Right: controls ──────────────────────────────────────────
            if isBatchMode {
                BatchControlsPanel(processor: batch)
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
            } else {
                ControlsPanel(processor: processor)
                    .frame(minWidth: 240, idealWidth: 260, maxWidth: 300)
            }
        }
        .frame(minWidth: 800, minHeight: 560)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    processor.clearImage()
                    batch.clear()
                } label: {
                    Label("Open New", systemImage: "photo.badge.plus")
                }
                .disabled(processor.sourceImage == nil && batch.isEmpty)
                .help("Clear current image(s) and start over")
            }
        }
        .onAppear { consumePendingExternalEdit() }
        .onChange(of: externalEdit.pendingURL) { _ in
            consumePendingExternalEdit()
        }
    }

    private func consumePendingExternalEdit() {
        guard let url = externalEdit.pendingURL else { return }
        batch.clear()
        processor.loadForRoundTrip(from: url)
        externalEdit.pendingURL = nil
    }
}
