import Foundation

/// Codable conversation history for MLX backend.
/// Serialized to `Conversation.transcriptData` — distinguished from
/// Foundation Models transcript by `conversation.modelBackend` field.
struct MLXTranscript: Codable, Sendable {
    var messages: [MLXMessage] = []

    struct MLXMessage: Codable, Sendable {
        let role: String  // "system", "user", "assistant", "tool"
        let content: String
    }

    mutating func addSystem(_ content: String) {
        messages.append(MLXMessage(role: "system", content: content))
    }

    mutating func addUser(_ content: String) {
        messages.append(MLXMessage(role: "user", content: content))
    }

    mutating func addAssistant(_ content: String) {
        messages.append(MLXMessage(role: "assistant", content: content))
    }

    mutating func addTool(_ content: String) {
        messages.append(MLXMessage(role: "tool", content: content))
    }

    var estimatedTokens: Int {
        messages.reduce(0) { $0 + ($1.content.count / 4) }
    }
}
