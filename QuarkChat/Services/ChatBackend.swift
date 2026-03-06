import Foundation
import FoundationModels

/// Protocol abstracting the language model backend.
/// Foundation Models and MLX each provide a conforming implementation.
protocol ChatBackend: AnyObject, Sendable {
    /// Create or restore a session for a conversation.
    func initializeSession(
        transcriptData: Data?,
        instructions: String,
        tools: [any Tool],
        toolDefinitions: [ToolDefinition]
    ) async

    /// Stream a response for the given prompt, calling `onToken` with incremental text
    /// and a flag indicating whether the model is currently reasoning internally.
    /// Returns the final complete response text.
    func streamResponse(
        prompt: String,
        onToken: @Sendable @escaping (_ text: String, _ isThinking: Bool) -> Void
    ) async throws -> String

    /// Whether the transcript is approaching the context limit.
    var needsCompaction: Bool { get async }

    /// Summarize old turns and rebuild the session.
    func compactTranscript(instructions: String) async

    /// Export transcript for persistence.
    func transcriptData() async -> Data?

    /// Clear session state.
    func invalidateSession() async

    /// Generate conversation starter suggestions.
    func generateStarters(recentTopics: [String]) async -> [String]

    /// Generate a short title for a conversation.
    func generateTitle(firstUserMessage: String) async -> String
}
