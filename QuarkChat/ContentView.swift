import SwiftUI
import SwiftData

private let welcomeVersionCurrent = 1
private let welcomeVersionKey = "welcome.version.seen"

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasInitialized = false
    @AppStorage(welcomeVersionKey) private var welcomeVersionSeen: Int = 0
    @State private var showWelcome = false

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
                    } else {
                        ContentUnavailableView("No Chat Selected", systemImage: "bubble.left.and.bubble.right")
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
            #if os(macOS)
            // macOS always shows the detail pane — keep it filled
            if newValue == nil && hasInitialized && appState.isModelAvailable {
                appState.selectedConversation = Conversation()
            }
            #endif
        }
        .sheet(isPresented: Binding(
            get: { appStateBindable.showOnboarding && appState.isModelAvailable },
            set: { appStateBindable.showOnboarding = $0 }
        )) {
            OnboardingView()
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeView {
                welcomeVersionSeen = welcomeVersionCurrent
                #if DEBUG
                welcomeVersionSeen = 0
                #endif
                showWelcome = false
            }
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
            // Show "What's New" for returning users after app updates
            if !appState.showOnboarding && welcomeVersionSeen < welcomeVersionCurrent {
                showWelcome = true
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
                #if os(macOS)
                // macOS always shows the detail pane — keep it filled
                if appState.isModelAvailable && appState.selectedConversation == nil && !appState.showOnboarding {
                    appState.selectedConversation = Conversation()
                }
                #endif
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [Conversation.self, Message.self, UserProfile.self], inMemory: true)
}
