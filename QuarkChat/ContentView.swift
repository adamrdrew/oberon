import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasInitialized = false

    var body: some View {
        @Bindable var appStateBindable = appState

        Group {
            if !hasInitialized {
                Color.clear
            } else if appState.isModelAvailable {
                NavigationSplitView {
                    ConversationListView()
                    #if os(macOS)
                        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
                    #endif
                } detail: {
                    if let conversation = appState.selectedConversation {
                        ChatView(conversation: conversation)
                            .id(conversation.id)
                    }
                }
            } else {
                ModelUnavailableView(availability: appState.modelAvailability) {
                    appState.checkAvailability()
                }
            }
        }
        .id(ThemeManager.shared.currentTheme.id)
        .onChange(of: appState.selectedConversation) { _, newValue in
            if newValue == nil && hasInitialized && appState.isModelAvailable {
                appState.selectedConversation = Conversation()
            }
        }
        .sheet(isPresented: Binding(
            get: { appStateBindable.showOnboarding && appState.isModelAvailable },
            set: { appStateBindable.showOnboarding = $0 }
        )) {
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
        .onChange(of: scenePhase) { _, phase in
            // Re-check when user returns from Settings after enabling Apple Intelligence
            if phase == .active && hasInitialized && !appState.isModelAvailable {
                appState.checkAvailability()
                // If model just became available, set up initial state
                if appState.isModelAvailable && appState.selectedConversation == nil && !appState.showOnboarding {
                    appState.selectedConversation = Conversation()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [Conversation.self, Message.self, UserProfile.self], inMemory: true)
}
