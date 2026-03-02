import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appStateBindable = appState

        NavigationSplitView {
            ConversationListView()
            #if os(macOS)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            #endif
        } detail: {
            if appState.isModelAvailable {
                if let conversation = appState.selectedConversation {
                    ChatView(conversation: conversation)
                        .id(conversation.id)
                } else {
                    ContentUnavailableView {
                        Label("QuarkChat", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Select a conversation or start a new chat.")
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Apple Intelligence Required", systemImage: "brain")
                } description: {
                    Text(appState.unavailableReason)
                }
            }
        }
        .task {
            appState.checkAvailability()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [Conversation.self, Message.self, UserProfile.self], inMemory: true)
}
