import Foundation
import Observation
import SwiftUI
import SwiftData
import FoundationModels
import MapKit

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

    let coordinator = MessageCoordinator()
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
        let result = await chatService.generateGreeting(userName: userProfile?.name)
        greetingHeadline = result.headline
        greetingSubtitle = result.subtitle
    }

    private func ensureSession() {
        guard !sessionCreated else { return }
        chatService.createSession(userProfile: userProfile)
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

        isGenerating = true

        // Build recent exchanges for classifier context
        let recentExchanges = messages.suffix(6).map { msg in
            (role: msg.role, content: msg.content)
        }

        // Find the last assistant message for conversation context
        let lastAssistantMessage = messages.last(where: { $0.role == "assistant" })?.content

        // Run pipeline
        let pipelineOutput = await coordinator.process(
            userMessage: text,
            recentExchanges: recentExchanges,
            userProfile: userProfile,
            lastAssistantMessage: lastAssistantMessage
        )

        // Stream final response from main session
        showTypingIndicator = true

        do {
            let responseText = try await chatService.streamResponse(to: pipelineOutput.enrichedPrompt)

            showTypingIndicator = false

            // Encode citations
            var citationsJSON: String?
            if !pipelineOutput.citations.isEmpty,
               let data = try? JSONEncoder().encode(pipelineOutput.citations) {
                citationsJSON = String(data: data, encoding: .utf8)
            }

            // Encode pipeline steps
            var pipelineStepsJSON: String?
            if !pipelineOutput.pipelineSteps.isEmpty,
               let data = try? JSONEncoder().encode(pipelineOutput.pipelineSteps) {
                pipelineStepsJSON = String(data: data, encoding: .utf8)
            }

            // Encode actions
            var actionsJSON: String?
            if !pipelineOutput.actions.isEmpty,
               let data = try? JSONEncoder().encode(pipelineOutput.actions) {
                actionsJSON = String(data: data, encoding: .utf8)
            }

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
                assistantMessage.conversation = conversation
                modelContext.insert(assistantMessage)
                conversation.updatedAt = Date()
                try? modelContext.save()
                messages.append(assistantMessage)
            }

            // Clear live pipeline steps now that they're persisted
            coordinator.pipelineSteps = []

            // Auto-execute primary action after message is persisted
            if let primaryAction = pipelineOutput.actions.first {
                executeAction(primaryAction)
            }

            // Generate title if first exchange
            if conversation.title == "New Chat" {
                let title = await chatService.generateTitle(firstUserMessage: text)
                conversation.title = title
                try? modelContext.save()
            }
        } catch let error as LanguageModelSession.GenerationError {
            showTypingIndicator = false
            coordinator.pipelineSteps = []
            handleGenerationError(error)
        } catch {
            showTypingIndicator = false
            coordinator.pipelineSteps = []
            errorMessage = error.localizedDescription
        }

        isGenerating = false
        chatService.clearStreamingState()
    }

    func stopGenerating() {
        isGenerating = false
        showTypingIndicator = false
    }

    func executeAction(_ action: PlaceAction) {
        switch action.type {
        case .directions:
            if let lat = action.latitude, let lon = action.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let placemark = MKPlacemark(coordinate: coordinate)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = action.placeName
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } else if let url = URL(string: action.urlString) {
                openURL(url)
            }

        case .call:
            if let url = URL(string: action.urlString) {
                openURL(url)
            }

        case .openWebsite:
            if let url = URL(string: action.urlString) {
                openURL(url)
            }
        }
    }

    private func openURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    private func handleGenerationError(_ error: LanguageModelSession.GenerationError) {
        switch error {
        case .guardrailViolation:
            errorMessage = "I can't help with that request."
        case .exceededContextWindowSize:
            errorMessage = "Context limit reached. Starting fresh context..."
            Task {
                await performCompaction()
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
            chatService.createSession(userProfile: userProfile)
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

    var serviceIsGenerating: Bool {
        chatService.isGenerating
    }
}
