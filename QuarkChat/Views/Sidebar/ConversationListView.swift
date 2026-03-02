import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Conversation.updatedAt, order: .reverse)
    private var conversations: [Conversation]

    @State private var viewModel = ConversationListViewModel()
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var userProfile: UserProfile?

    private var filteredConversations: [Conversation] {
        if searchText.isEmpty { return conversations }
        return conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        @Bindable var appStateBindable = appState

        List(selection: $appStateBindable.selectedConversation) {
            if filteredConversations.isEmpty {
                ContentUnavailableView {
                    Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Start a new chat to begin.")
                }
            } else {
                ForEach(filteredConversations) { conversation in
                    NavigationLink(value: conversation) {
                        ConversationRow(conversation: conversation)
                    }
                }
                .onDelete { offsets in
                    withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                        viewModel.deleteConversations(
                            at: offsets,
                            from: filteredConversations,
                            modelContext: modelContext,
                            appState: appState
                        )
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.25)) {
                        _ = viewModel.createNewConversation(
                            modelContext: modelContext,
                            userProfile: userProfile,
                            appState: appState
                        )
                    }
                } label: {
                    Label("New Chat", systemImage: "plus.bubble")
                        .symbolEffect(.bounce, value: viewModel.isCreatingConversation)
                }
                .buttonStyle(.glass)
                .disabled(viewModel.isCreatingConversation)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.glass)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .navigationTitle("QuarkChat")
        .task {
            loadUserProfile()
        }
    }

    private func loadUserProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        userProfile = try? modelContext.fetch(descriptor).first

        // Ensure a profile exists
        if userProfile == nil {
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            try? modelContext.save()
            userProfile = newProfile
        }
    }
}
