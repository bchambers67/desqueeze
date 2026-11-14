import SwiftUI

/// Options that apply to every photo.
///
/// The sheet is exactly as tall as its contents and has one size. A sheet
/// with two sizes changes material on the way between them, from floating
/// glass to an opaque full-height panel, which showed as a jump in colour and
/// position when it was dragged up. With one size there is nothing to change
/// between. New options are new rows; if they outgrow the screen, the sheet
/// scrolls.
struct SettingsSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 360

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Settings")
                        .font(Brand.sans(17, weight: .medium))
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                }

                section("EXPORT",
                        note: "Saved and shared photos get a white border on every side: 2% of the long edge for small, 5% for medium.") {
                    Toggle("Add a matte", isOn: $model.addsMatte)
                    if model.addsMatte {
                        Picker("Matte size", selection: $model.matteSize) {
                            ForEach(AppModel.MatteSize.allCases) { size in
                                Text(size.label).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                section("LIBRARY",
                        note: "Checks the last two weeks of your library for photos shot through an anamorphic lens that have not been corrected, and offers to queue them. It goes by the lens the camera recorded, by the shape of faces, text and bodies, by the direction of fine detail, and by photos you have already corrected from the same session. Your photos stay on this device.") {
                    Toggle("Find squeezed photos", isOn: $model.findsSqueezed)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .font(Brand.sans(15))
        .foregroundStyle(Brand.primary)
        .tint(Brand.accent)
        .animation(.smooth(duration: 0.2), value: model.addsMatte)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
    }

    private func section<Content: View>(_ title: String, note: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: title)
            content()
            Text(note)
                .font(Brand.sans(12))
                .foregroundStyle(Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
