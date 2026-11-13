import SwiftUI

/// Options that apply to every photo. A standard form, so the system supplies
/// the sheet's glass and the controls; new options are new rows.
struct SettingsSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Add a matte", isOn: $model.addsMatte)
                    if model.addsMatte {
                        Picker("Matte size", selection: $model.matteSize) {
                            ForEach(AppModel.MatteSize.allCases) { size in
                                Text(size.label).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("Export")
                } footer: {
                    Text("Saved and shared photos get a white border on every side: 2% of the long edge for small, 5% for medium. The preview shows the photo without it.")
                }

                Section {
                    Toggle("Find squeezed photos", isOn: $model.findsSqueezed)
                } header: {
                    Text("Library")
                } footer: {
                    Text("Checks the last two weeks of your library for photos shot through an anamorphic lens that have not been corrected, and offers to queue them. It goes by the lens the camera recorded, by the shape of faces, text and bodies, by the direction of fine detail, and by photos you have already corrected from the same session. Your photos stay on this device.")
                }
            }
            .tint(Brand.accent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
