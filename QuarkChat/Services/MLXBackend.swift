import Foundation
import MLX
import MLXLLM
import MLXLMCommon
@preconcurrency import FoundationModels

/// ChatBackend implementation using MLX with Qwen3 models.
/// Uses ChatSession for multi-turn conversation with KV cache.
/// Tool calls are detected via `streamDetails` and dispatched through `ToolRegistry`.
final class MLXBackend: ChatBackend, @unchecked Sendable {
    private let modelType: ModelBackendType
    private var chatSession: ChatSession?
    private var transcript = MLXTranscript()
    private var toolDefinitions: [ToolDefinition] = []
    private var currentInstructions: String = ""
    private var evictionObserver: NSObjectProtocol?

    init(modelType: ModelBackendType = .mlx) {
        self.modelType = modelType
    }

    deinit {
        if let evictionObserver {
            NotificationCenter.default.removeObserver(evictionObserver)
        }
    }

    // MARK: - Session Lifecycle

    func initializeSession(
        transcriptData: Data?,
        instructions: String,
        tools: [any FoundationModels.Tool],
        toolDefinitions: [ToolDefinition]
    ) async {
        self.toolDefinitions = toolDefinitions
        self.currentInstructions = instructions

        // Observe memory eviction — release chatSession so ModelContainer can be freed
        evictionObserver = NotificationCenter.default.addObserver(
            forName: MLXModelManager.didEvictNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.chatSession = nil
        }

        // Restore transcript if available
        if let data = transcriptData,
           let restored = try? JSONDecoder().decode(MLXTranscript.self, from: data) {
            transcript = restored
        } else {
            transcript = MLXTranscript()
        }

        await buildSession(instructions: instructions)
    }

    func invalidateSession() async {
        chatSession = nil
        transcript = MLXTranscript()
        toolDefinitions = []
        if let evictionObserver {
            NotificationCenter.default.removeObserver(evictionObserver)
            self.evictionObserver = nil
        }
    }

    func transcriptData() async -> Data? {
        try? JSONEncoder().encode(transcript)
    }

    // MARK: - Streaming

    func streamResponse(
        prompt: String,
        onToken: @Sendable @escaping (_ text: String, _ isThinking: Bool) -> Void
    ) async throws -> String {
        // Auto-reload if model was evicted (e.g., app backgrounded on iOS)
        if chatSession == nil {
            await buildSession(instructions: currentInstructions)
        }
        guard let chatSession else {
            throw ChatError.modelUnavailable
        }

        transcript.addUser(prompt)

        var fullText = ""
        var pendingToolCalls: [ToolCall] = []

        // Use streamDetails to capture both text chunks and tool calls
        for try await generation in chatSession.streamDetails(to: prompt, images: [], videos: []) {
            switch generation {
            case .chunk(let chunk):
                fullText += chunk
                let thinking = MLXToolCallParser.isInsideThinkBlock(fullText)
                let displayText = MLXToolCallParser.stripThinkingBlocks(fullText)
                onToken(displayText, thinking)
            case .toolCall(let toolCall):
                pendingToolCalls.append(toolCall)
            case .info:
                break
            }
        }

        // If tool calls were detected, execute them and continue generation
        if !pendingToolCalls.isEmpty {
            let toolResultText = await executeToolCalls(pendingToolCalls)

            // Feed tool results back to the model as a follow-up prompt
            var followUpText = ""
            for try await chunk in chatSession.streamResponse(to: toolResultText) {
                followUpText += chunk
                let thinking = MLXToolCallParser.isInsideThinkBlock(followUpText)
                let displayText = MLXToolCallParser.stripThinkingBlocks(followUpText)
                onToken(displayText, thinking)
            }

            let finalText = MLXToolCallParser.stripThinkingBlocks(followUpText)
            transcript.addAssistant(finalText)
            MLXModelManager.shared.flushCache()
            return finalText
        }

        let finalText = MLXToolCallParser.stripThinkingBlocks(fullText)

        transcript.addAssistant(finalText)
        MLXModelManager.shared.flushCache()
        return finalText
    }

    // MARK: - Compaction

    var needsCompaction: Bool {
        let threshold = modelType == .mlxBalanced
            ? TokenBudget.mlxBalancedCompactionThreshold
            : TokenBudget.mlxCompactionThreshold
        return transcript.estimatedTokens > threshold
    }

    func compactTranscript(instructions: String) async {
        let messages = transcript.messages

        // Keep last 10 messages (5 turn pairs)
        let keepCount = min(10, messages.count)
        let oldMessages = messages.dropLast(keepCount)
        let recentMessages = Array(messages.suffix(keepCount))

        guard oldMessages.count > 2 else { return }

        // Build text to summarize
        let oldText = oldMessages
            .filter { $0.role == "user" || $0.role == "assistant" }
            .map { "\($0.role.capitalized): \($0.content)" }
            .joined(separator: "\n")

        guard let container = try? await MLXModelManager.shared.loadModel(for: modelType) else { return }

        let summarySession = ChatSession(
            container,
            instructions: "Summarize this conversation concisely. Capture key topics, facts, and decisions. Under 150 words.",
            generateParameters: GenerateParameters(maxTokens: 256, temperature: 0.3),
            additionalContext: ["enable_thinking": false]
        )

        let summary: String
        do {
            summary = try await summarySession.respond(to: "Summarize:\n\(String(oldText.prefix(3000)))")
        } catch {
            return
        }

        // Rebuild transcript
        transcript = MLXTranscript()
        transcript.addSystem("\(instructions)\n\nConversation summary: \(summary)")
        for msg in recentMessages {
            transcript.messages.append(msg)
        }

        // Rebuild chat session
        let toolSpecs = buildToolSpecs()
        let history = buildChatHistory()

        chatSession = ChatSession(
            container,
            instructions: instructions + "\n\nConversation summary: \(summary)",
            history: history,
            generateParameters: GenerateParameters(
                maxTokens: 2048,
                temperature: 0.6,
                topP: 0.95
            ),
            tools: toolSpecs.isEmpty ? nil : toolSpecs,
            additionalContext: ["enable_thinking": true]
        )
    }

    // MARK: - Utility Sessions

    func generateStarters(recentTopics: [String]) async -> [String] {
        guard !recentTopics.isEmpty,
              let container = try? await MLXModelManager.shared.loadModel(for: modelType) else { return [] }

        let session = ChatSession(
            container,
            instructions: "You suggest conversation topics for a chat app. Output short phrases a user would type. NEVER use a question mark. Output exactly 3 items, one per line.",
            generateParameters: GenerateParameters(maxTokens: 256, temperature: 0.8),
            additionalContext: ["enable_thinking": false]
        )

        let prompt = "The user's recent interests include: \(recentTopics.joined(separator: ", ")). Suggest 3 NEW conversation topics they might enjoy — do NOT repeat or summarize their past chats. Each should be a fresh, short phrase (5-8 words). Output one per line."

        do {
            let response = try await session.respond(to: prompt)
            let stripped = MLXToolCallParser.stripThinkingBlocks(response)
            return stripped
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.replacingOccurrences(of: "?", with: "") }
                .filter { !$0.isEmpty && $0.count < 80 }
                .prefix(3)
                .map { String($0) }
        } catch {
            return []
        }
    }

    func generateTitle(firstUserMessage: String) async -> String {
        guard let container = try? await MLXModelManager.shared.loadModel(for: modelType) else { return "New Chat" }

        let session = ChatSession(
            container,
            instructions: "Create a 3-5 word title for a chat conversation. Return ONLY the title, nothing else. No quotes, no punctuation, no explanation.",
            generateParameters: GenerateParameters(maxTokens: 64, temperature: 0.5),
            additionalContext: ["enable_thinking": false]
        )

        do {
            let response = try await session.respond(to: "Title for: \(firstUserMessage)")
            let stripped = MLXToolCallParser.stripThinkingBlocks(response)
            let title = stripped
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !title.isEmpty else { return "New Chat" }
            return title
        } catch {
            return "New Chat"
        }
    }

    // MARK: - Private Helpers

    /// Build or rebuild the ChatSession from current transcript and instructions.
    /// Called during init and after memory eviction when the user returns.
    private func buildSession(instructions: String) async {
        guard let container = try? await MLXModelManager.shared.loadModel(for: modelType) else { return }

        MLX.Memory.cacheLimit = 20 * 1024 * 1024

        let toolSpecs = buildToolSpecs()
        let history = buildChatHistory()

        if history.isEmpty {
            chatSession = ChatSession(
                container,
                instructions: instructions,
                generateParameters: GenerateParameters(
                    maxTokens: 2048,
                    temperature: 0.6,
                    topP: 0.95
                ),
                tools: toolSpecs.isEmpty ? nil : toolSpecs,
                additionalContext: ["enable_thinking": true]
            )
        } else {
            chatSession = ChatSession(
                container,
                instructions: instructions,
                history: history,
                generateParameters: GenerateParameters(
                    maxTokens: 2048,
                    temperature: 0.6,
                    topP: 0.95
                ),
                tools: toolSpecs.isEmpty ? nil : toolSpecs,
                additionalContext: ["enable_thinking": true]
            )
        }
    }

    private func buildChatHistory() -> [Chat.Message] {
        transcript.messages.compactMap { msg -> Chat.Message? in
            let role: Chat.Message.Role = switch msg.role {
            case "system": .system
            case "assistant": .assistant
            case "tool": .tool
            default: .user
            }
            return Chat.Message(role: role, content: msg.content)
        }
    }

    private func buildToolSpecs() -> [[String: any Sendable]] {
        toolDefinitions.map { def in
            var properties: [String: any Sendable] = [:]
            var required: [String] = []

            for param in def.parameters {
                properties[param.name] = [
                    "type": param.type,
                    "description": param.description,
                ] as [String: any Sendable]
                if param.required {
                    required.append(param.name)
                }
            }

            return [
                "type": "function",
                "function": [
                    "name": def.name,
                    "description": def.description,
                    "parameters": [
                        "type": "object",
                        "properties": properties,
                        "required": required,
                    ] as [String: any Sendable],
                ] as [String: any Sendable],
            ] as [String: any Sendable]
        }
    }

    private func executeToolCalls(_ toolCalls: [ToolCall]) async -> String {
        var results: [String] = []

        for toolCall in toolCalls {
            let name = toolCall.function.name
            let args: [String: Any] = toolCall.function.arguments.reduce(into: [:]) { result, pair in
                switch pair.value {
                case .string(let s): result[pair.key] = s
                case .int(let i): result[pair.key] = i
                case .double(let d): result[pair.key] = d
                case .bool(let b): result[pair.key] = b
                default: result[pair.key] = "\(pair.value)"
                }
            }

            do {
                let result = try await ToolRegistry.shared.execute(name: name, arguments: args)
                transcript.addTool(result)
                results.append("Tool '\(name)' result: \(result)")
            } catch {
                results.append("Tool '\(name)' failed: \(error.localizedDescription)")
            }
        }

        return results.joined(separator: "\n\n")
    }
}
