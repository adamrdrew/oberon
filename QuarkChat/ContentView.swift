import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var hasInitialized = false

    var body: some View {
        @Bindable var appStateBindable = appState

        NavigationSplitView {
            ConversationListView()
            #if os(macOS)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            #endif
        } detail: {
            if !hasInitialized {
                Color.clear
            } else if appState.isModelAvailable {
                if let conversation = appState.selectedConversation {
                    ChatView(conversation: conversation)
                        .id(conversation.id)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "brain")
                        .font(.system(size: 40, design: .monospaced))
                        .foregroundStyle(QTheme.quarkAccent)
                    Text("APPLE INTELLIGENCE REQUIRED")
                        .font(QTheme.sectionHeader)
                        .textCase(.uppercase)
                        .tracking(3)
                        .foregroundStyle(QTheme.quarkSecondary)
                    Text(appState.unavailableReason)
                        .font(QTheme.bodySmall)
                        .foregroundStyle(QTheme.quarkTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .id(ThemeManager.shared.currentTheme.id)
        .onChange(of: appState.selectedConversation) { _, newValue in
            if newValue == nil && hasInitialized && appState.isModelAvailable {
                appState.selectedConversation = Conversation()
            }
        }
        .sheet(isPresented: $appStateBindable.showOnboarding) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
        .task {
            // Load persisted theme once at startup (not on .id() rebuilds)
            if !ThemeManager.shared.hasLoadedInitialTheme {
                let profileDescriptor = FetchDescriptor<UserProfile>()
                if let profile = try? modelContext.fetch(profileDescriptor).first {
                    ThemeManager.shared.applyTheme(id: profile.themeID)
                    // Check onboarding status
                    if !profile.hasCompletedOnboarding {
                        appState.showOnboarding = true
                    }
                } else {
                    // No profile yet — onboarding will create one
                    appState.showOnboarding = true
                }
                ThemeManager.shared.hasLoadedInitialTheme = true
            }

            appState.checkAvailability()
            if !appState.showOnboarding && appState.isModelAvailable && appState.selectedConversation == nil {
                let conversation = Conversation()
                appState.selectedConversation = conversation
            }
            hasInitialized = true
        }
        .onChange(of: appState.showOnboarding) { _, isShowing in
            // After onboarding dismisses, create the initial conversation
            if !isShowing && appState.isModelAvailable && appState.selectedConversation == nil {
                appState.selectedConversation = Conversation()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [Conversation.self, Message.self, UserProfile.self], inMemory: true)
}
