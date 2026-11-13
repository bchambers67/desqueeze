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
                    Toggle("Add a 5% matte", isOn: $model.addsMatte)
                } header: {
                    Text("Export")
                } footer: {
                    Text("Saved and shared photos get a white border, 5% of the long edge on every side. The preview shows the photo without it.")
                }

                Section {
                    Toggle("Find squeezed photos", isOn: $model.findsSqueezed)
                } header: {
                    Text("Library")
                } footer: {
                    Text("Checks the last two weeks of your library for photos shot through an anamorphic lens that have not been corrected, and offers to queue them. It goes by the lens the camera recorded and by the shape of faces. Your photos stay on this device.")
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
