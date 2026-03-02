import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ConversationListViewModel {
    var isCreatingConversation: Bool = false

    func createNewConversation(
        modelContext: ModelContext,
        userProfile: UserProfile?,
        appState: AppState
    ) -> Conversation {
        isCreatingConversation = true
        defer { isCreatingConversation = false }

        let conversation = Conversation()
        modelContext.insert(conversation)
        try? modelContext.save()
        appState.selectedConversation = conversation
        return conversation
    }

    func deleteConversation(_ conversation: Conversation, modelContext: ModelContext, appState: AppState) {
        if appState.selectedConversation?.id == conversation.id {
            appState.selectedConversation = nil
        }
        modelContext.delete(conversation)
        try? modelContext.save()
    }

    func deleteConversations(at offsets: IndexSet, from conversations: [Conversation], modelContext: ModelContext, appState: AppState) {
        for index in offsets {
            deleteConversation(conversations[index], modelContext: modelContext, appState: appState)
        }
    }

    func deleteConversations(withIDs ids: Set<UUID>, from conversations: [Conversation], modelContext: ModelContext, appState: AppState) {
        for conversation in conversations where ids.contains(conversation.id) {
            deleteConversation(conversation, modelContext: modelContext, appState: appState)
        }
    }
}
