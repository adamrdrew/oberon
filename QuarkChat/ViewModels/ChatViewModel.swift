import Foundation
import Observation
import SwiftUI
import SwiftData
import FoundationModels
import MapKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
    var greetingHeadline: String?
    var greetingSubtitle: String?
    var showGreeting: Bool = true
    var scrollTargetMessageID: UUID?

    let coordinator = MessageCoordinator()
    let ttsService = TTSService()
    let speechService = SpeechService()
    private let chatService = ChatService()
    private var conversation: Conversation?
    private var modelContext: ModelContext?
    private var userProfile: UserProfile?

    /// Suggested replies from the latest assistant message
    var currentSuggestedReplies: [SuggestedReply]? {
        messages.last(where: { $0.role == "assistant" })?.suggestedReplies.isEmpty == false
            ? messages.last(where: { $0.role == "assistant" })?.suggestedReplies
            : nil
    }

    func configure(conversation: Conversation, modelContext: ModelContext, userProfile: UserProfile?) {
        self.conversation = conversation
        self.modelContext = modelContext
        self.userProfile = userProfile
        self.userBubbleColor = userProfile?.favoriteColorHex ?? "#007AFF"
        loadMessages()

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
        let result = await chatService.generateGreeting(userName: userProfile?.name)
        greetingHeadline = result.headline
        greetingSubtitle = result.subtitle
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, let conversation, let modelContext else { return }

        inputText = ""
        errorMessage = nil
        showGreeting = false

        // Persist user message
        let nextIndex = messages.count
        let userMessage = Message(content: text, role: "user", sortIndex: nextIndex)
        userMessage.conversation = conversation
        modelContext.insert(userMessage)
        conversation.updatedAt = Date()
        try? modelContext.save()
        messages.append(userMessage)
        scrollTargetMessageID = userMessage.id

        isGenerating = true

        // Build recent exchanges for classifier context
        let recentExchanges = messages.suffix(6).map { msg in
            (role: msg.role, content: msg.content)
        }

        // Find the last assistant message for clipboard processor
        let lastAssistantMessage = messages.last(where: { $0.role == "assistant" })?.content

        // Run pipeline
        let pipelineOutput = await coordinator.process(
            userMessage: text,
            recentExchanges: recentExchanges,
            userProfile: userProfile,
            lastAssistantMessage: lastAssistantMessage
        )

        // Assemble fresh-session prompt
        let assembled = PromptAssembler.assemble(
            conversationSummary: conversation.summary,
            userProfile: userProfile,
            enrichedPrompt: pipelineOutput.enrichedPrompt,
            intent: pipelineOutput.intent
        )

        // Stream response from fresh session
        showTypingIndicator = true

        var responseText: String?
        do {
            responseText = try await chatService.streamResponse(
                instructions: assembled.instructions,
                prompt: assembled.prompt
            )
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                errorMessage = "That was too complex. Try a shorter question."
            case .guardrailViolation:
                errorMessage = "I can't help with that."
            default:
                errorMessage = "Something went wrong."
            }
        } catch {
            errorMessage = "Something went wrong."
        }

        showTypingIndicator = false

        guard let responseText else {
            coordinator.pipelineSteps = []
            isGenerating = false
            chatService.clearStreamingState()
            return
        }

        // Encode all metadata
        let citationsJSON = encodeJSON(pipelineOutput.citations)
        let pipelineStepsJSON = encodeJSON(pipelineOutput.pipelineSteps)
        let actionsJSON = encodeJSON(pipelineOutput.actions)
        let richContentJSON = encodeJSON(pipelineOutput.richContent)
        let suggestedRepliesJSON = encodeJSON(pipelineOutput.suggestedReplies)

        // Clear streaming state and append final message without animation
        var noAnimation = Transaction(animation: .none)
        noAnimation.disablesAnimations = true
        withTransaction(noAnimation) {
            chatService.clearStreamingState()
            let assistantMessage = Message(
                content: responseText,
                role: "assistant",
                sortIndex: messages.count
            )
            assistantMessage.citationsJSON = citationsJSON
            assistantMessage.pipelineStepsJSON = pipelineStepsJSON
            assistantMessage.actionsJSON = actionsJSON
            assistantMessage.richContentJSON = richContentJSON
            assistantMessage.suggestedRepliesJSON = suggestedRepliesJSON
            assistantMessage.conversation = conversation
            modelContext.insert(assistantMessage)
            conversation.updatedAt = Date()
            try? modelContext.save()
            messages.append(assistantMessage)
        }

        // Clear live pipeline steps now that they're persisted
        coordinator.pipelineSteps = []

        // Auto-execute primary action after message is persisted
        if let primaryAction = pipelineOutput.actions.first, primaryAction.autoExecutes {
            executeAction(primaryAction)
        }

        // Generate title if first exchange
        if conversation.title == "New Chat" {
            let title = await chatService.generateTitle(firstUserMessage: text)
            conversation.title = title
            try? modelContext.save()
        }

        isGenerating = false
        chatService.clearStreamingState()

        // Update rolling summary in background
        let currentSummary = conversation.summary
        let finalResponse = responseText
        Task {
            let updated = await chatService.updateRollingSummary(
                existing: currentSummary,
                userMessage: text,
                response: finalResponse
            )
            conversation.summary = updated
            try? modelContext.save()
        }
    }

    func stopGenerating() {
        isGenerating = false
        showTypingIndicator = false
    }

    // MARK: - Action Execution

    func executeAction(_ action: RichAction) {
        switch action.type {
        case .directions:
            if let lat = action.latitude, let lon = action.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let placemark = MKPlacemark(coordinate: coordinate)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = action.subtitle
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } else if let urlString = action.urlString, let url = URL(string: urlString) {
                openURL(url)
            }

        case .call, .callContact, .openWebsite, .sendEmail, .messageContact,
             .openReminders, .openCalendar, .openTimer, .openTranslation:
            if let urlString = action.urlString, let url = URL(string: urlString) {
                openURL(url)
            }

        case .openApp:
            if let urlString = action.urlString, let url = URL(string: urlString) {
                openURL(url)
            }

        case .copyToClipboard:
            if let text = action.payload?["text"] {
                copyToClipboard(text)
            }

        case .playMusic:
            // Music playback is handled by MusicProcessor directly
            break

        case .shareContent:
            // Share sheet would be handled via ChatView presentation
            break
        }
    }

    // MARK: - TTS

    func toggleSpeech(for message: Message) {
        ttsService.speak(text: message.content, messageID: message.id)
    }

    // MARK: - Copy

    func copyMessage(_ message: Message) {
        copyToClipboard(message.content)
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    // MARK: - Helpers

    private func openURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    private func encodeJSON<T: Encodable>(_ value: [T]) -> String? {
        guard !value.isEmpty,
              let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // Observe chat service state for UI updates
    var serviceStreamText: String {
        chatService.currentStreamText
    }

    var serviceIsGenerating: Bool {
        chatService.isGenerating
    }
}
