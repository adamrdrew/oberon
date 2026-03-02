import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = SettingsViewModel()
    @State private var profile: UserProfile?

    var body: some View {
        NavigationStack {
            Form {
                Section("About You") {
                    TextField("Name", text: $viewModel.name)
                    TextField("Location", text: $viewModel.location)

                    VStack(alignment: .leading) {
                        TextField("About Me", text: $viewModel.aboutMe, axis: .vertical)
                            .lineLimit(3...6)
                        Text("\(viewModel.aboutMeRemaining) characters remaining")
                            .font(.caption)
                            .foregroundStyle(viewModel.aboutMeRemaining < 0 ? .red : .secondary)
                    }
                }

                Section("Response Style") {
                    VStack(alignment: .leading) {
                        TextField("How should Quark respond?", text: $viewModel.responsePreference, axis: .vertical)
                            .lineLimit(3...6)
                        Text("\(viewModel.responsePrefRemaining) characters remaining")
                            .font(.caption)
                            .foregroundStyle(viewModel.responsePrefRemaining < 0 ? .red : .secondary)
                    }
                }

                Section("Appearance") {
                    ColorPicker("Bubble Color", selection: $viewModel.favoriteColor)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(context: modelContext)
                        try? modelContext.save()
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .task {
            loadProfile()
        }
    }

    private func loadProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? modelContext.fetch(descriptor).first {
            profile = existing
            viewModel.load(from: existing)
        }
    }
}
