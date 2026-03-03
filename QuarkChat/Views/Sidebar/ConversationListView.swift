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

    private var userInitial: String {
        if let name = userProfile?.name, let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }

    private var userName: String {
        if let name = userProfile?.name, !name.isEmpty {
            return name
        }
        return "User"
    }

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            Group {
                if isEditing {
                    editModeList
                } else {
                    navigationList
                }
            }
            .searchable(text: $searchText, prompt: "Search conversations")

            sidebarFooter
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
        .task {
            loadUserProfile()
        }
    }

    // MARK: - Sidebar Header

    @ViewBuilder
    private var sidebarHeader: some View {
        VStack(spacing: 0) {
            StripeAccentView()

            VStack(spacing: 2) {
                // New Chat
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.25)) {
                        _ = viewModel.createNewConversation(
                            modelContext: modelContext,
                            userProfile: userProfile,
                            appState: appState
                        )
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 15))
                            .frame(width: 20)
                        Text("New Chat")
                            .font(QTheme.label)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isCreatingConversation || isEditing)
                .opacity(isEditing ? 0.4 : 1)

                // Edit / Done
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        if isEditing {
                            multiSelection.removeAll()
                        }
                        isEditing.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isEditing ? "checkmark.circle" : "pencil")
                            .font(.system(size: 15))
                            .frame(width: 20)
                        Text(isEditing ? "Done" : "Edit")
                            .font(QTheme.label)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(conversations.isEmpty)

                // Delete (only in edit mode)
                if isEditing {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .frame(width: 20)
                            Text("Delete (\(multiSelection.count))")
                                .font(QTheme.label)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(multiSelection.isEmpty ? QTheme.quarkTertiary : QTheme.quarkSignalRed)
                    .disabled(multiSelection.isEmpty)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.background)
    }

    // MARK: - Sidebar Footer

    @ViewBuilder
    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                showSettings = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(QTheme.quarkAccent)
                            .frame(width: 30, height: 30)
                        Text(userInitial)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    Text(userName)
                        .font(QTheme.label)
                        .foregroundStyle(QTheme.quarkPrimary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(.background)
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
                        .font(QTheme.bodySmall)
                }
            } else {
                Section {
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
                        .font(QTheme.bodySmall)
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
