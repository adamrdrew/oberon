import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var viewModel = SettingsViewModel()
    @State private var profile: UserProfile?
    @State private var originalThemeID: String = "quark"
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {

                    // MARK: - Theme Picker

                    settingsSection("Theme") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(QuarkColorTheme.allThemes) { theme in
                                    ThemePreviewCard(
                                        theme: theme,
                                        isSelected: viewModel.selectedThemeID == theme.id
                                    ) {
                                        viewModel.selectedThemeID = theme.id
                                        // Update bubble color to match new theme's first band
                                        viewModel.favoriteColorHex = theme.band3Hex
                                        // Live preview
                                        ThemeManager.shared.applyTheme(id: theme.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                        }
                    }

                    // MARK: - About You

                    settingsSection("About You") {
                        VStack(spacing: 16) {
                            settingsField("Name", text: $viewModel.name)
                            settingsField("Location", text: $viewModel.location)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("About Me")
                                    .font(QTheme.caption)
                                    .foregroundStyle(QTheme.quarkSecondary)
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                TextField("Tell Quark about yourself...", text: $viewModel.aboutMe, axis: .vertical)
                                    .font(QTheme.body)
                                    .lineLimit(3...6)
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: .rect(cornerRadius: QTheme.cornerRadiusCard))
                                HStack {
                                    Spacer()
                                    Text("\(viewModel.aboutMeRemaining)")
                                        .font(QTheme.timestamp)
                                        .foregroundStyle(viewModel.aboutMeRemaining < 0 ? QTheme.quarkSignalRed : QTheme.quarkTertiary)
                                }
                            }
                        }
                    }

                    // MARK: - Response Style

                    settingsSection("Response Style") {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("How should Quark respond?", text: $viewModel.responsePreference, axis: .vertical)
                                .font(QTheme.body)
                                .lineLimit(3...6)
                                .padding(12)
                                .background(.ultraThinMaterial, in: .rect(cornerRadius: QTheme.cornerRadiusCard))
                            HStack {
                                Spacer()
                                Text("\(viewModel.responsePrefRemaining)")
                                    .font(QTheme.timestamp)
                                    .foregroundStyle(viewModel.responsePrefRemaining < 0 ? QTheme.quarkSignalRed : QTheme.quarkTertiary)
                            }
                        }
                    }

                    // MARK: - Bubble Color

                    settingsSection("Bubble Color") {
                        HStack(spacing: 12) {
                            ForEach(QTheme.bubbleSwatches.indices, id: \.self) { index in
                                let swatch = QTheme.bubbleSwatches[index]
                                Button {
                                    viewModel.favoriteColorHex = swatch.hex
                                } label: {
                                    RoundedRectangle(cornerRadius: QTheme.cornerRadiusSmall)
                                        .fill(swatch.color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: QTheme.cornerRadiusSmall)
                                                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                                        )
                                        .overlay {
                                            if viewModel.favoriteColorHex == swatch.hex {
                                                Image(systemName: "checkmark")
                                                    .font(QTheme.caption.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(swatch.name)
                            }
                            Spacer()
                        }
                    }

                    // MARK: - Delete All Data

                    settingsSection("Data") {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                    .font(.system(size: 15))
                                Text("Delete All Data")
                                    .font(QTheme.label)
                            }
                            .foregroundStyle(QTheme.quarkSignalRed)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: .rect(cornerRadius: QTheme.cornerRadiusCard))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .background(QTheme.quarkBackground)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will delete all conversations and reset your profile. This cannot be undone.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Revert live preview to original theme
                        ThemeManager.shared.applyTheme(id: originalThemeID)
                        dismiss()
                    }
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
            originalThemeID = viewModel.selectedThemeID
        }
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(QTheme.sectionHeader)
                .foregroundStyle(QTheme.quarkSecondary)
                .textCase(.uppercase)
                .tracking(3)
            content()
        }
    }

    // MARK: - Text Field Builder

    private func settingsField(_ placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(placeholder)
                .font(QTheme.caption)
                .foregroundStyle(QTheme.quarkSecondary)
                .textCase(.uppercase)
                .tracking(1.5)
            TextField(placeholder, text: text)
                .font(QTheme.body)
                .padding(12)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: QTheme.cornerRadiusCard))
        }
    }

    // MARK: - Load Profile

    private func loadProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? modelContext.fetch(descriptor).first {
            profile = existing
            viewModel.load(from: existing)
        }
    }

    // MARK: - Delete All Data

    private func deleteAllData() {
        // Delete all conversations (messages cascade via relationship)
        let conversations = (try? modelContext.fetch(FetchDescriptor<Conversation>())) ?? []
        for conversation in conversations {
            modelContext.delete(conversation)
        }

        // Reset profile for onboarding
        if let profile {
            profile.name = ""
            profile.location = ""
            profile.aboutMe = ""
            profile.responsePreference = ""
            profile.favoriteColorHex = "#1E2D4D"
            profile.themeID = "quark"
            profile.hasCompletedOnboarding = false
        }

        try? modelContext.save()

        // Reset theme to default
        ThemeManager.shared.applyTheme(id: "quark")

        // Clear selected conversation and trigger onboarding
        appState.selectedConversation = nil
        appState.showOnboarding = true
        dismiss()
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let theme: QuarkColorTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // 5 band color stripes
                VStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        theme.stripeColors[index]
                            .frame(height: 6)
                    }
                }
                .clipShape(.rect(cornerRadius: QTheme.cornerRadiusSmall))
                .frame(width: 72)

                Text(theme.displayName)
                    .font(QTheme.pipelineLabel)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(isSelected ? QTheme.quarkAccent : QTheme.quarkSecondary)
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: QTheme.cornerRadiusCard)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: QTheme.cornerRadiusCard)
                            .strokeBorder(
                                isSelected ? QTheme.quarkAccent : .clear,
                                lineWidth: 2
                            )
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
