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
    var userBubbleColor: String = "#1E2D4D"
    var greetingHeadline: String?
    var greetingSubtitle: String?
    var showGreeting: Bool = true
    var scrollTargetMessageID: UUID?

    /// Live pipeline steps from current tool calls (drained after response)
    var livePipelineSteps: [PipelineStep] = []

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
        // Invalidate previous session if switching conversations
        if self.conversation?.id != conversation.id {
            chatService.invalidateSession()
        }

        self.conversation = conversation
        self.modelContext = modelContext
        self.userProfile = userProfile
        self.userBubbleColor = userProfile?.favoriteColorHex ?? "#1E2D4D"
        loadMessages()

        // Build tools with user context injected
        let tools = buildTools(userProfile: userProfile)

        // Initialize persistent session with tools
        let instructions = PromptAssembler.buildInstructions(userProfile: userProfile)
        chatService.initializeSession(
            transcriptData: conversation.transcriptData,
            instructions: instructions,
            tools: tools
        )

        if messages.isEmpty {
            showGreeting = true
            setFallbackGreeting()
            Task {
                await generateGreeting()
            }
        } else {
            showGreeting = false
        }
    }

    private func buildTools(userProfile: UserProfile?) -> [any Tool] {
        let location = userProfile?.location
        return [
            WebSearchTool(),
            SearchNearbyTool(userLocation: location),
            GetWeatherTool(userLocation: location),
            CalculatorTool(),
        ]
    }

    private func loadMessages() {
        guard let conversation else { return }
        messages = conversation.sortedMessages
    }

    private func setFallbackGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = hour < 12 ? "morning" : (hour < 17 ? "afternoon" : "evening")
        let name = (userProfile?.name.isEmpty == false) ? userProfile!.name : "there"
        greetingHeadline = "Good \(timeOfDay), \(name)!"
        greetingSubtitle = "Ready for whatever you need."
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

        // Insert conversation into SwiftData on first message
        if conversation.modelContext == nil {
            modelContext.insert(conversation)
        }

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

        // Check compaction before sending
        if chatService.needsCompaction {
            let instructions = PromptAssembler.buildInstructions(userProfile: userProfile)
            await chatService.compactTranscript(instructions: instructions)
        }

        // Stream response — session handles tool calling transparently
        showTypingIndicator = true

        // Start polling for live pipeline steps (detached to avoid MainActor contention)
        let stepPollTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                let steps = await ToolResultStore.shared.pipelineSteps
                await MainActor.run {
                    self?.livePipelineSteps = steps
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }

        var responseText: String?
        do {
            responseText = try await chatService.streamResponse(prompt: text)
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                // Reactive fallback: force compaction and retry
                let instructions = PromptAssembler.buildInstructions(userProfile: userProfile)
                await chatService.compactTranscript(instructions: instructions)
                do {
                    responseText = try await chatService.streamResponse(prompt: text)
                } catch {
                    errorMessage = "That was too complex. Try a shorter question."
                }
            case .guardrailViolation:
                errorMessage = "I can't help with that."
            default:
                errorMessage = "Something went wrong."
            }
        } catch {
            errorMessage = "Something went wrong."
        }

        stepPollTask.cancel()
        showTypingIndicator = false

        guard let responseText else {
            livePipelineSteps = []
            isGenerating = false
            chatService.clearStreamingState()
            return
        }

        // Drain tool results
        let toolResults = await ToolResultStore.shared.takeAll()

        // Encode all metadata
        let citationsJSON = encodeJSON(toolResults.citations)
        let pipelineStepsJSON = encodeJSON(toolResults.pipelineSteps)
        let actionsJSON = encodeJSON(toolResults.actions)
        let richContentJSON = encodeJSON(toolResults.richContent)
        let suggestedRepliesJSON = encodeJSON(toolResults.suggestedReplies)

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

            // Save transcript to conversation for persistence
            conversation.transcriptData = chatService.transcriptData()
            conversation.updatedAt = Date()
            try? modelContext.save()
            messages.append(assistantMessage)
        }

        // Clear live pipeline steps now that they're persisted
        livePipelineSteps = []

        // Auto-execute primary action after message is persisted
        if let primaryAction = toolResults.actions.first, primaryAction.autoExecutes {
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

        case .call, .openWebsite:
            if let urlString = action.urlString, let url = URL(string: urlString) {
                openURL(url)
            }

        case .copyToClipboard:
            if let text = action.payload?["text"] {
                copyToClipboard(text)
            }
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
