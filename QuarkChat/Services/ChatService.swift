import Foundation
import Observation
import FoundationModels

@Observable
final class ChatService {
    var currentStreamText: String = ""
    var activeToolName: String?
    var isGenerating: Bool = false

    private var session: LanguageModelSession?

    // MARK: - Session Management

    func createSession(
        userProfile: UserProfile?,
        tools: [any Tool],
        existingTranscript: Transcript? = nil
    ) {
        let instructions = buildInstructions(userProfile: userProfile)

        if let transcript = existingTranscript {
            // Transcript already contains instructions from the original session
            session = LanguageModelSession(
                model: SystemLanguageModel.default,
                tools: tools,
                transcript: transcript
            )
        } else {
            session = LanguageModelSession(
                model: SystemLanguageModel.default,
                tools: tools,
                instructions: instructions
            )
        }
        session?.prewarm()
    }

    func buildInstructions(userProfile: UserProfile?) -> String {
        var parts: [String] = []
        parts.append("You are Quark, a friendly, helpful AI assistant. Be concise and conversational.")
        parts.append("You have tools. Use web_search for ANY question about current events, weather, news, sports scores, facts you're unsure about, or anything that benefits from up-to-date info. Use current_datetime when the user asks about the time or date.")
        parts.append("ALWAYS use web_search rather than guessing when you don't know the answer.")

        if let profile = userProfile {
            if !profile.name.isEmpty {
                parts.append("The user's name is \(profile.name).")
            }
            if !profile.location.isEmpty {
                parts.append("They're in \(profile.location).")
            }
            if !profile.aboutMe.isEmpty {
                parts.append("About them: \(profile.aboutMe)")
            }
            if !profile.responsePreference.isEmpty {
                parts.append("Response style: \(profile.responsePreference)")
            }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Streaming Response

    @MainActor
    func streamResponse(to prompt: String) async throws -> String {
        guard let session else {
            throw ChatError.sessionNotCreated
        }

        isGenerating = true
        currentStreamText = ""
        activeToolName = nil

        // Poll transcript for tool calls on a separate cadence,
        // because the stream yields NO snapshots while a tool executes.
        let pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.detectActiveToolUse()
                try? await Task.sleep(for: .milliseconds(150))
            }
        }

        defer {
            pollTask.cancel()
            isGenerating = false
            activeToolName = nil
        }

        let stream = session.streamResponse(to: prompt)
        var finalText = ""

        for try await snapshot in stream {
            currentStreamText = snapshot.content
            finalText = snapshot.content
        }

        _ = try await stream.collect()
        return finalText
    }

    private func detectActiveToolUse() {
        guard let transcript = session?.transcript else { return }
        let entries = Array(transcript)

        // Walk backward to find the most recent tool call without a matching output
        for entry in entries.reversed() {
            if case .toolOutput = entry {
                activeToolName = nil
                return
            }
            if case .toolCalls(let calls) = entry {
                if let name = calls.first?.toolName, !name.isEmpty {
                    activeToolName = name
                }
                return
            }
            if case .response = entry {
                activeToolName = nil
                return
            }
        }
    }

    // MARK: - Context Compaction

    func compactContext(messages: [Message], userProfile: UserProfile?) async -> String? {
        let compactionSession = LanguageModelSession(
            instructions: "Summarize the following conversation in 2-3 sentences. Focus on key topics, decisions, and user preferences."
        )

        let messageText = messages.prefix(20).map { msg in
            "\(msg.role): \(msg.content)"
        }.joined(separator: "\n")

        do {
            let response = try await compactionSession.respond(to: messageText)
            return response.content
        } catch {
            return nil
        }
    }

    func needsCompaction(messages: [Message]) -> Bool {
        let totalChars = messages.reduce(0) { $0 + $1.content.count }
        let estimatedTokens = totalChars / 4
        return estimatedTokens > 2000 || messages.count > 16
    }

    // MARK: - Utility Sessions

    func generateGreeting(userName: String?) async -> String {
        let session = LanguageModelSession(
            instructions: "Generate a brief, warm greeting. One sentence only."
        )

        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = hour < 12 ? "morning" : (hour < 17 ? "afternoon" : "evening")

        let prompt: String
        if let name = userName, !name.isEmpty {
            prompt = "Greet \(name) in the \(timeOfDay). Be friendly and brief."
        } else {
            prompt = "Greet the user in the \(timeOfDay). Be friendly and brief."
        }

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            return userName.map { "Hi \($0)! How can I help you today?" }
                ?? "Hello! How can I help you today?"
        }
    }

    func generateTitle(firstUserMessage: String) async -> String {
        let session = LanguageModelSession(
            instructions: "Create a 3-5 word title for a chat conversation. Return ONLY the title, nothing else."
        )

        do {
            let response = try await session.respond(to: "Title for: \(firstUserMessage)")
            let title = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip quotes if model wraps in them
            return title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        } catch {
            return "New Chat"
        }
    }

    func clearStreamingState() {
        currentStreamText = ""
        activeToolName = nil
    }

    func invalidateSession() {
        session = nil
    }
}

enum ChatError: LocalizedError {
    case sessionNotCreated
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionNotCreated:
            return "Chat session not initialized."
        case .modelUnavailable:
            return "The language model is not available."
        }
    }
}
