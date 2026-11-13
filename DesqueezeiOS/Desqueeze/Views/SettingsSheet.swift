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
            }
            .tint(Brand.coral)
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
