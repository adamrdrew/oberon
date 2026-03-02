import Foundation
import Observation
import SwiftUI
import SwiftData
import FoundationModels

@Observable
@MainActor
final class ChatViewModel {
    var messages: [Message] = []
    var isGenerating: Bool = false
    var inputText: String = ""
    var showTypingIndicator: Bool = false
    var errorMessage: String?
    var isUserScrolledUp: Bool = false
    var userBubbleColor: String = "#007AFF"
    var greetingText: String?
    var showGreeting: Bool = true

    private let chatService = ChatService()
    private var conversation: Conversation?
    private var modelContext: ModelContext?
    private var userProfile: UserProfile?
    private var sessionCreated = false

    func configure(conversation: Conversation, modelContext: ModelContext, userProfile: UserProfile?) {
        self.conversation = conversation
        self.modelContext = modelContext
        self.userProfile = userProfile
        self.userBubbleColor = userProfile?.favoriteColorHex ?? "#007AFF"
        loadMessages()

        // Show greeting overlay for new (empty) conversations
        if messages.isEmpty {
            showGreeting = true
            Task {
                await generateGreeting()
            }
        } else {
            showGreeting = false
        }
    }

    private func loadMessages() {
        guard let conversation else { return }
        messages = conversation.sortedMessages
    }

    private func generateGreeting() async {
        let greeting = await chatService.generateGreeting(userName: userProfile?.name)
        greetingText = greeting
    }

    private func ensureSession() {
        guard !sessionCreated else { return }
        let tools: [any Tool] = [WebSearchTool(), DateTimeTool()]
        chatService.createSession(userProfile: userProfile, tools: tools)
        sessionCreated = true
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, let conversation, let modelContext else { return }

        inputText = ""
        errorMessage = nil
        showGreeting = false
        ensureSession()

        // Persist user message
        let nextIndex = messages.count
        let userMessage = Message(content: text, role: "user", sortIndex: nextIndex)
        userMessage.conversation = conversation
        modelContext.insert(userMessage)
        conversation.updatedAt = Date()
        try? modelContext.save()
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            messages.append(userMessage)
        }

        // Check compaction
        if chatService.needsCompaction(messages: messages) {
            await performCompaction()
        }

        // Show typing indicator
        showTypingIndicator = true
        isGenerating = true

        do {
            let responseText = try await chatService.streamResponse(to: text)

            showTypingIndicator = false

            // Clear streaming state and append final message without animation.
            // The user already watched the text stream in — no need for a second entrance.
            var noAnimation = Transaction(animation: .none)
            noAnimation.disablesAnimations = true
            withTransaction(noAnimation) {
                chatService.clearStreamingState()
                let assistantMessage = Message(
                    content: responseText,
                    role: "assistant",
                    sortIndex: messages.count
                )
                assistantMessage.conversation = conversation
                modelContext.insert(assistantMessage)
                conversation.updatedAt = Date()
                try? modelContext.save()
                messages.append(assistantMessage)
            }

            // Generate title if first exchange
            if conversation.title == "New Chat" {
                let title = await chatService.generateTitle(firstUserMessage: text)
                conversation.title = title
                try? modelContext.save()
            }
        } catch let error as LanguageModelSession.GenerationError {
            showTypingIndicator = false
            handleGenerationError(error)
        } catch {
            showTypingIndicator = false
            errorMessage = error.localizedDescription
        }

        isGenerating = false
        chatService.clearStreamingState()
    }

    func stopGenerating() {
        // Foundation Models doesn't have a cancel API; we just stop observing
        isGenerating = false
        showTypingIndicator = false
    }

    private func handleGenerationError(_ error: LanguageModelSession.GenerationError) {
        switch error {
        case .guardrailViolation:
            errorMessage = "I can't help with that request."
        case .exceededContextWindowSize:
            errorMessage = "Context limit reached. Starting fresh context..."
            Task {
                await performCompaction()
                // Recreate session with compacted context
                sessionCreated = false
            }
        case .rateLimited:
            errorMessage = "Too many requests. Please wait a moment."
        default:
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func performCompaction() async {
        guard let conversation else { return }

        if let summary = await chatService.compactContext(messages: messages, userProfile: userProfile) {
            conversation.summary = summary

            // Recreate session with summary as context
            sessionCreated = false
            let tools: [any Tool] = [WebSearchTool(), DateTimeTool()]
            chatService.createSession(userProfile: userProfile, tools: tools)
            sessionCreated = true

            // Send summary as context to new session
            _ = try? await chatService.streamResponse(
                to: "Previous conversation summary: \(summary)\nContinue the conversation naturally."
            )
        }
    }

    // Observe chat service state for UI updates
    var serviceStreamText: String {
        chatService.currentStreamText
    }

    var serviceActiveToolName: String? {
        chatService.activeToolName
    }

    var serviceIsGenerating: Bool {
        chatService.isGenerating
    }
}
