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
    @State private var isEditing = false
    @State private var multiSelection: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    private var filteredConversations: [Conversation] {
        if searchText.isEmpty { return conversations }
        return conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if isEditing {
                editModeList
            } else {
                navigationList
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
                .disabled(viewModel.isCreatingConversation || isEditing)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.glass)
            }

            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        if isEditing {
                            multiSelection.removeAll()
                        }
                        isEditing.toggle()
                    }
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                }
                .disabled(conversations.isEmpty)
            }

            if isEditing {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text("Delete (\(multiSelection.count))")
                    }
                    .disabled(multiSelection.isEmpty)
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        if isEditing {
                            multiSelection.removeAll()
                        }
                        isEditing.toggle()
                    }
                } label: {
                    Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark.circle" : "checkmark.circle")
                }
                .disabled(conversations.isEmpty)
            }

            if isEditing {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete (\(multiSelection.count))", systemImage: "trash")
                    }
                    .disabled(multiSelection.isEmpty)
                }
            }
            #endif
        }
        .alert("Delete Conversations", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete \(multiSelection.count) Conversation\(multiSelection.count == 1 ? "" : "s")", role: .destructive) {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    viewModel.deleteConversations(
                        withIDs: multiSelection,
                        from: conversations,
                        modelContext: modelContext,
                        appState: appState
                    )
                    multiSelection.removeAll()
                    isEditing = false
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .navigationTitle("QuarkChat")
        .task {
            loadUserProfile()
        }
    }

    // MARK: - Navigation List (normal mode)

    @ViewBuilder
    private var navigationList: some View {
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
                    #if os(macOS)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                                if appState.selectedConversation == conversation {
                                    appState.selectedConversation = nil
                                }
                                modelContext.delete(conversation)
                                try? modelContext.save()
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    #endif
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
    }

    // MARK: - Edit Mode List (multi-select)

    @ViewBuilder
    private var editModeList: some View {
        List(selection: $multiSelection) {
            if filteredConversations.isEmpty {
                ContentUnavailableView {
                    Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Start a new chat to begin.")
                }
            } else {
                ForEach(filteredConversations) { conversation in
                    ConversationRow(conversation: conversation)
                        .tag(conversation.id)
                }
            }
        }
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
    }

    // MARK: - Helpers

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
