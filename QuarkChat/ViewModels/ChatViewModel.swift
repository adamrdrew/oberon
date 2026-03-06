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

enum VoiceModeStatus {
    case listening, thinking, speaking
}

@Observable
@MainActor
final class ChatViewModel {
    var messages: [Message] = []
    var isGenerating: Bool = false
    var inputText: String = ""
    var showTypingIndicator: Bool = false
    var errorMessage: String?
    var userBubbleColor: String = "#1E2D4D"
    var greetingHeadline: String?
    var greetingSubtitle: String?
    var showGreeting: Bool = true
    var scrollTargetMessageID: UUID?
    var conversationStarters: [String] = []

    // MARK: - Voice Mode
    var isVoiceMode: Bool = false
    var voiceModeStatus: VoiceModeStatus = .listening

    /// Live pipeline steps from current tool calls (drained after response)
    var livePipelineSteps: [PipelineStep] = []

    let ttsService = TTSService()
    let speechService = SpeechService()
    private let chatService = ChatService()
    private var conversation: Conversation?
    private var modelContext: ModelContext?
    private var userProfile: UserProfile?
    private var greetingTask: Task<Void, Never>?

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
        ttsService.selectedVoiceID = userProfile?.selectedVoiceID ?? ""
        loadMessages()

        // Set backend type from user preference (default: foundation)
        let backendStr = userProfile?.selectedModelBackend ?? ModelBackendType.foundation.rawValue
        chatService.backendType = ModelBackendType(rawValue: backendStr) ?? .foundation

        // Build tools with user context injected
        let tools = buildTools(userProfile: userProfile, backendType: chatService.backendType)
        let toolDefinitions = Self.buildToolDefinitions(backendType: chatService.backendType)

        // Initialize persistent session with tools
        let instructions = PromptAssembler.buildInstructions(userProfile: userProfile, backendType: chatService.backendType)
        chatService.initializeSession(
            transcriptData: conversation.transcriptData,
            instructions: instructions,
            tools: tools,
            toolDefinitions: toolDefinitions
        )

        if messages.isEmpty {
            showGreeting = true
            conversationStarters = []
            setGreeting()
            greetingTask?.cancel()
            greetingTask = Task {
                await loadConversationStarters()
            }
        } else {
            showGreeting = false
            conversationStarters = []
        }
    }

    private func buildTools(userProfile: UserProfile?, backendType: ModelBackendType) -> [any Tool] {
        var tools: [any Tool] = [
            WebSearchTool(),
            ImageSearchTool(),
            VideoSearchTool(),
            URLReaderTool(),
        ]

        if backendType == .mlx {
            tools.append(WikipediaTool())
        }

        // Register executors in ToolRegistry for MLX backend
        Task {
            let registry = ToolRegistry.shared
            await registry.clear()

            await registry.register(name: "web_search") { args in
                let query = args["query"] as? String ?? ""
                let tool = WebSearchTool()
                return try await tool.call(arguments: .init(query: query))
            }
            await registry.register(name: "image_search") { args in
                let query = args["query"] as? String ?? ""
                let tool = ImageSearchTool()
                return try await tool.call(arguments: .init(query: query))
            }
            await registry.register(name: "video_search") { args in
                let query = args["query"] as? String ?? ""
                let tool = VideoSearchTool()
                return try await tool.call(arguments: .init(query: query))
            }
            await registry.register(name: "read_url") { args in
                let url = args["url"] as? String ?? ""
                let tool = URLReaderTool()
                return try await tool.call(arguments: .init(url: url))
            }
            if backendType == .mlx {
                await registry.register(name: "wikipedia") { args in
                    let topic = args["topic"] as? String ?? ""
                    let tool = WikipediaTool()
                    return try await tool.call(arguments: .init(topic: topic))
                }
            }
        }

        return tools
    }

    /// Build backend-agnostic tool definitions for MLX system prompt.
    private static func buildToolDefinitions(backendType: ModelBackendType) -> [ToolDefinition] {
        var definitions = [
            ToolDefinition(
                name: "web_search",
                description: "Search the web for current information, news, facts, or anything you don't know.",
                parameters: [.init(name: "query", type: "string", description: "Search query", required: true)]
            ),
            ToolDefinition(
                name: "image_search",
                description: "Search for images on the web.",
                parameters: [.init(name: "query", type: "string", description: "Image search query", required: true)]
            ),
            ToolDefinition(
                name: "video_search",
                description: "Search for videos on the web.",
                parameters: [.init(name: "query", type: "string", description: "Video search query", required: true)]
            ),
            ToolDefinition(
                name: "read_url",
                description: "Read and extract content from a URL.",
                parameters: [.init(name: "url", type: "string", description: "The URL to read", required: true)]
            ),
        ]

        if backendType == .mlx {
            definitions.append(ToolDefinition(
                name: "wikipedia",
                description: "Look up a topic on Wikipedia to show the user a rich article card.",
                parameters: [.init(name: "topic", type: "string", description: "The topic to look up", required: true)]
            ))
        }

        return definitions
    }

    private func loadMessages() {
        guard let conversation else { return }
        messages = conversation.sortedMessages
    }

    private func setGreeting() {
        let name = (userProfile?.name.isEmpty == false) ? userProfile!.name : "there"
        let hour = Calendar.current.component(.hour, from: Date())

        let morningHeadlines = [
            "Good morning, \(name)!",
            "Morning, \(name)!",
            "Rise and shine, \(name)!",
            "Hey \(name), good morning!",
            "Top of the morning, \(name)!",
            "Bright and early, \(name)!",
            "Hello, \(name)!",
            "Welcome back, \(name)!",
        ]

        let afternoonHeadlines = [
            "Good afternoon, \(name)!",
            "Hey \(name)!",
            "Hi there, \(name)!",
            "What's up, \(name)!",
            "Welcome back, \(name)!",
            "Hello, \(name)!",
            "Howdy, \(name)!",
            "Hey hey, \(name)!",
        ]

        let eveningHeadlines = [
            "Good evening, \(name)!",
            "Evening, \(name)!",
            "Hey \(name)!",
            "Welcome back, \(name)!",
            "Hi there, \(name)!",
            "Hello, \(name)!",
            "Hey hey, \(name)!",
            "What's up, \(name)!",
        ]

        let subtitles = [
            "Ready for whatever you need.",
            "Let's see what we can do.",
            "What are we getting into today.",
            "Here whenever you need me.",
            "Let's get started.",
            "At your service.",
            "Standing by and ready.",
            "Let's make it a good one.",
            "What's on your mind.",
            "Ready when you are.",
            "Let's do this.",
            "Fire away.",
            "All ears.",
            "What can I help with.",
            "Back at it.",
            "Let's pick up where we left off.",
        ]

        let headlines: [String]
        if hour < 12 {
            headlines = morningHeadlines
        } else if hour < 17 {
            headlines = afternoonHeadlines
        } else {
            headlines = eveningHeadlines
        }

        greetingHeadline = headlines.randomElement()!
        greetingSubtitle = subtitles.randomElement()!
    }

    private func loadConversationStarters() async {
        let recentTopics = fetchRecentTopics()
        guard !recentTopics.isEmpty else { return }
        let starters = await chatService.generateStarters(recentTopics: recentTopics)
        guard !Task.isCancelled else { return }
        conversationStarters = starters
    }

    private func fetchRecentTopics() -> [String] {
        guard let modelContext else { return [] }
        var descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 3
        guard let conversations = try? modelContext.fetch(descriptor) else { return [] }
        return conversations
            .map(\.title)
            .filter { $0 != "New Chat" && !$0.isEmpty }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating, let conversation, let modelContext else { return }

        inputText = ""
        ttsService.selectedVoiceID = userProfile?.selectedVoiceID ?? ""
        if isVoiceMode { SoundEffectService.playSent() }
        errorMessage = nil
        showGreeting = false
        conversationStarters = []

        // Insert conversation into SwiftData on first message
        if conversation.modelContext == nil {
            modelContext.insert(conversation)
            conversation.modelBackend = chatService.backendType.rawValue
        }

        // Persist user message
        let nextIndex = messages.count
        let userMessage = Message(content: text, role: "user", sortIndex: nextIndex)
        userMessage.conversation = conversation
        modelContext.insert(userMessage)
        conversation.updatedAt = Date()
        modelContext.safeSave()
        messages.append(userMessage)
        scrollTargetMessageID = userMessage.id

        isGenerating = true

        // Check compaction before sending
        if chatService.needsCompaction {
            let instructions = PromptAssembler.buildInstructions(userProfile: userProfile, backendType: chatService.backendType)
            await chatService.compactTranscript(instructions: instructions)
        }

        // Stream response — session handles tool calling transparently
        showTypingIndicator = true
        if isVoiceMode { SoundEffectService.startThinking() }

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
                let instructions = PromptAssembler.buildInstructions(userProfile: userProfile, backendType: chatService.backendType)
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
            // Drain any stale tool results so they don't leak into future conversations
            _ = await ToolResultStore.shared.takeAll()
            livePipelineSteps = []
            isGenerating = false
            chatService.clearStreamingState()
            if isVoiceMode {
                SoundEffectService.stopThinking()
                voiceModeStatus = .listening
                SoundEffectService.playListening()
                Task { await speechService.startRecording() }
            }
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

        // Fetch transcript data before synchronous transaction block
        let transcriptSnapshot = await chatService.transcriptData()

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

            conversation.transcriptData = transcriptSnapshot
            conversation.updatedAt = Date()
            modelContext.safeSave()
            messages.append(assistantMessage)
        }

        // Clear live pipeline steps now that they're persisted
        livePipelineSteps = []
        Haptics.landed()

        // Voice mode: stop thinking loop before TTS speaks
        if isVoiceMode {
            SoundEffectService.stopThinking()
        }

        // Voice mode: auto-speak the response
        if isVoiceMode, let lastAssistant = messages.last, lastAssistant.role == "assistant" {
            voiceModeStatus = .speaking
            ttsService.speak(text: lastAssistant.content, messageID: lastAssistant.id)
        }

        // Auto-execute primary action after message is persisted
        if let primaryAction = toolResults.actions.first {
            executeAction(primaryAction)
        }

        // Generate title if first exchange
        if conversation.title == "New Chat" {
            let title = await chatService.generateTitle(firstUserMessage: text)
            conversation.title = title
            modelContext.safeSave()
        }

        isGenerating = false
        chatService.clearStreamingState()
    }

    func stopGenerating() {
        isGenerating = false
        showTypingIndicator = false
    }

    // MARK: - Voice Mode

    func toggleVoiceMode() {
        if isVoiceMode {
            disableVoiceMode()
        } else {
            enableVoiceMode()
        }
    }

    func disableVoiceMode() {
        isVoiceMode = false
        voiceModeStatus = .listening
        speechService.onSpeechFinalized = nil
        ttsService.onFinishedSpeaking = nil
        if speechService.isRecording {
            _ = speechService.stopRecording()
        }
        ttsService.stop()
        SoundEffectService.stopThinking()
        Haptics.tap()

        AudioSessionHelper.deactivateSession()
    }

    private func enableVoiceMode() {
        isVoiceMode = true
        voiceModeStatus = .listening
        Haptics.tap()

        AudioSessionHelper.activatePlaybackSession()

        SoundEffectService.playListening()

        speechService.onSpeechFinalized = { [weak self] text in
            guard let self, self.isVoiceMode else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                // Empty transcription — restart recording
                Task { await self.speechService.startRecording() }
                return
            }
            self.inputText = trimmed
            self.voiceModeStatus = .thinking
            Task { await self.sendMessage() }
        }

        ttsService.onFinishedSpeaking = { [weak self] in
            guard let self, self.isVoiceMode else { return }
            self.voiceModeStatus = .listening
            SoundEffectService.playListening()
            Task { await self.speechService.startRecording() }
        }

        Task { await speechService.startRecording() }
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
        ttsService.selectedVoiceID = userProfile?.selectedVoiceID ?? ""
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

    var isModelThinking: Bool {
        chatService.isModelThinking
    }

}
