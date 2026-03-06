import Foundation
import FoundationModels

/// ChatBackend implementation using Apple Foundation Models.
/// Extracted from the original ChatService — all session, streaming,
/// compaction, and utility logic lives here.
final class FoundationModelBackend: ChatBackend, @unchecked Sendable {
    private var session: LanguageModelSession?
    private var estimatedTokens: Int = 0
    private var registeredTools: [any Tool] = []

    // MARK: - Session Lifecycle

    func initializeSession(
        transcriptData: Data?,
        instructions: String,
        tools: [any Tool],
        toolDefinitions: [ToolDefinition]
    ) async {
        self.registeredTools = tools

        if let data = transcriptData,
           let transcript = try? JSONDecoder().decode(Transcript.self, from: data) {
            session = LanguageModelSession(
                model: .default,
                tools: tools,
                transcript: transcript
            )
            estimatedTokens = TokenBudget.estimateTokens(for: transcript)
        } else {
            session = LanguageModelSession(
                model: SystemLanguageModel(guardrails: .permissiveContentTransformations),
                tools: tools,
                instructions: instructions
            )
            estimatedTokens = TokenBudget.estimateTokens(instructions)
        }

        session?.prewarm()
    }

    func invalidateSession() async {
        session = nil
        estimatedTokens = 0
        registeredTools = []
    }

    func transcriptData() async -> Data? {
        guard let session else { return nil }
        return try? JSONEncoder().encode(session.transcript)
    }

    // MARK: - Streaming

    func streamResponse(
        prompt: String,
        onToken: @Sendable @escaping (_ text: String, _ isThinking: Bool) -> Void
    ) async throws -> String {
        guard let session else {
            throw ChatError.modelUnavailable
        }

        let stream = session.streamResponse(to: prompt)
        var finalText = ""

        for try await snapshot in stream {
            let content = snapshot.content
            guard content != "null" else { continue }
            onToken(content, false)
            finalText = content
        }

        estimatedTokens += TokenBudget.estimateTokens(prompt) + TokenBudget.estimateTokens(finalText)
        return finalText
    }

    // MARK: - Compaction

    var needsCompaction: Bool {
        estimatedTokens > TokenBudget.compactionThreshold
    }

    func compactTranscript(instructions: String) async {
        guard let session else { return }

        let transcript = session.transcript
        let entries = Array(transcript)

        guard entries.count > 8 else { return }

        var oldTurnTexts: [String] = []
        var promptResponsePairs: [(prompt: String, response: String)] = []
        var currentPrompt: String?

        for entry in entries {
            switch entry {
            case .instructions:
                break
            case .prompt(let p):
                let text = p.segments.compactMap { segment -> String? in
                    if case .text(let t) = segment { return t.content }
                    return nil
                }.joined()
                currentPrompt = text
            case .response(let r):
                let text = r.segments.compactMap { segment -> String? in
                    if case .text(let t) = segment { return t.content }
                    return nil
                }.joined()
                if let prompt = currentPrompt {
                    promptResponsePairs.append((prompt: prompt, response: text))
                    currentPrompt = nil
                }
            default:
                break
            }
        }

        let keepCount = min(3, promptResponsePairs.count)
        let oldPairs = promptResponsePairs.dropLast(keepCount)
        let recentPairs = promptResponsePairs.suffix(keepCount)

        guard !oldPairs.isEmpty else { return }

        for pair in oldPairs {
            oldTurnTexts.append("User: \(pair.prompt)\nAssistant: \(pair.response)")
        }
        let oldText = oldTurnTexts.joined(separator: "\n\n")

        let summarySession = LanguageModelSession(
            instructions: "Summarize this conversation concisely. Capture key topics, facts discussed, and any decisions made. Under 150 words."
        )

        let summary: String
        do {
            let response = try await summarySession.respond(
                to: "Summarize:\n\(String(oldText.prefix(2000)))"
            )
            summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return
        }

        let newInstructions = "\(instructions)\n\nConversation summary: \(summary)"

        var newEntries: [Transcript.Entry] = [
            .instructions(.init(
                id: UUID().uuidString,
                segments: [.text(.init(id: UUID().uuidString, content: newInstructions))],
                toolDefinitions: []
            ))
        ]

        for pair in recentPairs {
            newEntries.append(.prompt(.init(
                id: UUID().uuidString,
                segments: [.text(.init(id: UUID().uuidString, content: pair.prompt))]
            )))
            newEntries.append(.response(.init(
                id: UUID().uuidString,
                assetIDs: [],
                segments: [.text(.init(id: UUID().uuidString, content: pair.response))]
            )))
        }

        let newTranscript = Transcript(entries: newEntries)
        self.session = LanguageModelSession(
            model: .default,
            tools: registeredTools,
            transcript: newTranscript
        )
        self.estimatedTokens = TokenBudget.estimateTokens(for: newTranscript)
        self.session?.prewarm()
    }

    // MARK: - Utility Sessions

    @Generable
    struct GeneratedStarters {
        @Guide(description: "Exactly 3 conversation starters (5-8 words each). These suggest NEW topics the user might enjoy based on their interests — never repeat or summarize their past conversations. Each is a short phrase a user would type to start a chat.")
        var starters: [String]
    }

    func generateStarters(recentTopics: [String]) async -> [String] {
        guard !recentTopics.isEmpty else { return [] }

        let session = LanguageModelSession(
            instructions: "You suggest conversation topics for a chat app. Output short phrases a user would type. NEVER use a question mark."
        )

        let prompt = "The user's recent interests include: \(recentTopics.joined(separator: ", ")). Suggest 3 NEW conversation topics they might enjoy — do NOT repeat or summarize their past chats. Each should be a fresh, short phrase (5-8 words) like 'Latest discoveries in space exploration' or 'Best weekend hiking trails nearby'."

        do {
            let response = try await session.respond(to: prompt, generating: GeneratedStarters.self)
            return response.content.starters.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "?", with: "")
            }
        } catch {
            return []
        }
    }

    func generateTitle(firstUserMessage: String) async -> String {
        let session = LanguageModelSession(
            instructions: "Create a 3-5 word title for a chat conversation. Return ONLY the title, nothing else."
        )

        do {
            let response = try await session.respond(to: "Title for: \(firstUserMessage)")
            let title = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        } catch {
            return "New Chat"
        }
    }
}
