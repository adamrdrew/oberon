import Foundation
import Observation
import FoundationModels

@Observable
final class ChatService {
    var currentStreamText: String = ""
    var isGenerating: Bool = false
    var isModelThinking: Bool = false

    var needsCompaction: Bool {
        _cachedNeedsCompaction
    }

    private var activeBackend: (any ChatBackend)?
    private var _cachedNeedsCompaction: Bool = false

    // MARK: - Backend Management

    var backendType: ModelBackendType = .foundation

    /// Create or restore a persistent session for a conversation.
    func initializeSession(
        transcriptData: Data?,
        instructions: String,
        tools: [any Tool],
        toolDefinitions: [ToolDefinition] = []
    ) {
        // Create the appropriate backend
        switch backendType {
        case .foundation:
            activeBackend = FoundationModelBackend()
        case .mlxBalanced:
            activeBackend = MLXBackend(modelType: .mlxBalanced)
        case .mlx:
            activeBackend = MLXBackend(modelType: .mlx)
        }

        Task {
            await activeBackend?.initializeSession(
                transcriptData: transcriptData,
                instructions: instructions,
                tools: tools,
                toolDefinitions: toolDefinitions
            )
            let compaction = await activeBackend?.needsCompaction ?? false
            await MainActor.run { self._cachedNeedsCompaction = compaction }
        }
    }

    /// Clear session when switching conversations.
    func invalidateSession() {
        Task { await activeBackend?.invalidateSession() }
        activeBackend = nil
        _cachedNeedsCompaction = false
        clearStreamingState()
    }

    /// Export transcript for persistence.
    func transcriptData() async -> Data? {
        await activeBackend?.transcriptData()
    }

    // MARK: - Streaming Response

    func streamResponse(prompt: String) async throws -> String {
        guard let backend = activeBackend else {
            throw ChatError.modelUnavailable
        }

        await MainActor.run {
            isGenerating = true
            isModelThinking = false
            currentStreamText = ""
        }

        let finalText: String
        do {
            finalText = try await backend.streamResponse(prompt: prompt) { [weak self] text, thinking in
                guard let self else { return }
                Task { @MainActor in
                    self.currentStreamText = text
                    self.isModelThinking = thinking
                }
            }
        } catch {
            await MainActor.run { self.isGenerating = false }
            throw error
        }

        // Update cached compaction state
        let compaction = await backend.needsCompaction
        await MainActor.run {
            self.isGenerating = false
            self._cachedNeedsCompaction = compaction
        }

        return finalText
    }

    // MARK: - Compaction

    func compactTranscript(instructions: String) async {
        await activeBackend?.compactTranscript(instructions: instructions)
        let compaction = await activeBackend?.needsCompaction ?? false
        await MainActor.run { self._cachedNeedsCompaction = compaction }
    }

    // MARK: - Utility

    func generateStarters(recentTopics: [String]) async -> [String] {
        await activeBackend?.generateStarters(recentTopics: recentTopics) ?? []
    }

    func generateTitle(firstUserMessage: String) async -> String {
        await activeBackend?.generateTitle(firstUserMessage: firstUserMessage) ?? "New Chat"
    }

    func clearStreamingState() {
        currentStreamText = ""
        isModelThinking = false
    }
}

enum ChatError: LocalizedError {
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "The language model is not available."
        }
    }
}
