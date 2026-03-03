import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var viewModel = SettingsViewModel()
    @State private var profile: UserProfile?

    private let totalPages = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StripeAccentView()

                // Page content
                ScrollView {
                    Group {
                        switch page {
                        case 0: welcomePage
                        case 1: aboutYouPage
                        case 2: personalizePage
                        case 3: allSetPage
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                }

                Divider()

                // Bottom nav bar
                bottomBar
            }
            .background(OTheme.background)
            .navigationTitle("Welcome")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .interactiveDismissDisabled()
        .task {
            loadOrCreateProfile()
        }
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            Image(systemName: "atom")
                .font(.system(size: 64))
                .foregroundStyle(OTheme.accent)

            VStack(spacing: 12) {
                Text("Welcome to\nOberon")
                    .font(OTheme.displayLarge)
                    .foregroundStyle(OTheme.primary)
                    .multilineTextAlignment(.center)

                Text("Your local AI assistant")
                    .font(OTheme.body)
                    .foregroundStyle(OTheme.secondary)

                VStack(spacing: 8) {
                    Label("AI runs entirely on your device", systemImage: "lock.shield")
                    Label("You are in control of your data", systemImage: "hand.raised")
                }
                .font(OTheme.bodySmall)
                .foregroundStyle(OTheme.tertiary)
                .padding(.top, 8)
            }

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Page 1: About You

    private var aboutYouPage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("About You")
                    .font(OTheme.displayLarge)
                    .foregroundStyle(OTheme.primary)
                Text("Help Oberon get to know you.")
                    .font(OTheme.bodySmall)
                    .foregroundStyle(OTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                onboardingField("Name", text: $viewModel.name, placeholder: "Your name")
                onboardingField("Location", text: $viewModel.location, placeholder: "City, Country")

                VStack(alignment: .leading, spacing: 6) {
                    Text("About Me")
                        .font(OTheme.caption)
                        .foregroundStyle(OTheme.secondary)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    TextField("Tell Oberon about yourself...", text: $viewModel.aboutMe, axis: .vertical)
                        .font(OTheme.body)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: OTheme.cornerRadiusCard))
                    HStack {
                        Spacer()
                        Text("\(viewModel.aboutMeRemaining)")
                            .font(OTheme.timestamp)
                            .foregroundStyle(viewModel.aboutMeRemaining < 0 ? OTheme.signalRed : OTheme.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Response Style")
                        .font(OTheme.caption)
                        .foregroundStyle(OTheme.secondary)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    TextField("How should Oberon respond?", text: $viewModel.responsePreference, axis: .vertical)
                        .font(OTheme.body)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: OTheme.cornerRadiusCard))
                    HStack {
                        Spacer()
                        Text("\(viewModel.responsePrefRemaining)")
                            .font(OTheme.timestamp)
                            .foregroundStyle(viewModel.responsePrefRemaining < 0 ? OTheme.signalRed : OTheme.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Page 2: Personalize

    private var personalizePage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Personalize")
                    .font(OTheme.displayLarge)
                    .foregroundStyle(OTheme.primary)
                Text("Choose a theme that feels right.")
                    .font(OTheme.bodySmall)
                    .foregroundStyle(OTheme.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Theme picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(OTheme.sectionHeader)
                    .foregroundStyle(OTheme.secondary)
                    .textCase(.uppercase)
                    .tracking(3)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ColorTheme.allThemes) { theme in
                            ThemePreviewCard(
                                theme: theme,
                                isSelected: viewModel.selectedThemeID == theme.id
                            ) {
                                Haptics.selection()
                                viewModel.selectedThemeID = theme.id
                                viewModel.favoriteColorHex = theme.band3Hex
                                ThemeManager.shared.applyTheme(id: theme.id)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
            }

            // Bubble color
            VStack(alignment: .leading, spacing: 12) {
                Text("Bubble Color")
                    .font(OTheme.sectionHeader)
                    .foregroundStyle(OTheme.secondary)
                    .textCase(.uppercase)
                    .tracking(3)

                HStack(spacing: 12) {
                    ForEach(OTheme.bubbleSwatches.indices, id: \.self) { index in
                        let swatch = OTheme.bubbleSwatches[index]
                        Button {
                            Haptics.selection()
                            viewModel.favoriteColorHex = swatch.hex
                        } label: {
                            RoundedRectangle(cornerRadius: OTheme.cornerRadiusSmall)
                                .fill(swatch.color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: OTheme.cornerRadiusSmall)
                                        .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                                )
                                .overlay {
                                    if viewModel.favoriteColorHex == swatch.hex {
                                        Image(systemName: "checkmark")
                                            .font(OTheme.caption.bold())
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
        }
    }

    // MARK: - Page 3: All Set

    private var allSetPage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(OTheme.accent)

            VStack(spacing: 8) {
                Text("You're All Set")
                    .font(OTheme.displayLarge)
                    .foregroundStyle(OTheme.primary)
                Text("Oberon is ready to chat.")
                    .font(OTheme.bodySmall)
                    .foregroundStyle(OTheme.secondary)
            }

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Back button
            if page > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        page -= 1
                    }
                }
                .buttonStyle(.plain)
                .font(OTheme.label)
                .foregroundStyle(OTheme.secondary)
            } else {
                Spacer()
                    .frame(width: 60)
            }

            Spacer()

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == page ? OTheme.accent : OTheme.tertiary.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            // Next / Get Started
            if page < totalPages - 1 {
                Button("Next") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        page += 1
                    }
                }
                .buttonStyle(.glassProminent)
                .font(OTheme.label)
                .disabled(page == 1 && viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Button("Get Started") {
                    completeOnboarding()
                }
                .buttonStyle(.glassProminent)
                .font(OTheme.label)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Field Builder

    private func onboardingField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(OTheme.caption)
                .foregroundStyle(OTheme.secondary)
                .textCase(.uppercase)
                .tracking(1.5)
            TextField(placeholder, text: text)
                .font(OTheme.body)
                .padding(12)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: OTheme.cornerRadiusCard))
        }
    }

    // MARK: - Profile Management

    private func loadOrCreateProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? modelContext.fetch(descriptor).first {
            profile = existing
            viewModel.load(from: existing)
        } else {
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            try? modelContext.save()
            profile = newProfile
            viewModel.load(from: newProfile)
        }
    }

    private func completeOnboarding() {
        viewModel.save(context: modelContext)
        profile?.hasCompletedOnboarding = true
        try? modelContext.save()
        dismiss()
    }
}
