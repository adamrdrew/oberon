import Foundation
import Observation
import FoundationModels

@Observable
final class ChatService {
    var currentStreamText: String = ""
    var isGenerating: Bool = false

    // MARK: - Streaming Response (fresh session per turn)

    @MainActor
    func streamResponse(instructions: String, prompt: String) async throws -> String {
        isGenerating = true
        currentStreamText = ""

        defer {
            isGenerating = false
        }

        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(
            model: model,
            instructions: instructions
        )

        let stream = session.streamResponse(to: prompt)
        var finalText = ""

        for try await snapshot in stream {
            currentStreamText = snapshot.content
            finalText = snapshot.content
        }

        _ = try await stream.collect()
        return finalText
    }

    // MARK: - Rolling Summary

    func updateRollingSummary(
        existing: String,
        userMessage: String,
        response: String
    ) async -> String {
        let session = LanguageModelSession(
            instructions: "Update the conversation summary. Under 100 words. Capture the topic, key facts, and compress the last 2-3 Q&A pairs."
        )

        let cappedUser = String(userMessage.prefix(400))
        let cappedResponse = String(response.prefix(400))
        let cappedExisting = TokenBudget.capConversationContext(existing)

        let prompt: String
        if cappedExisting.isEmpty {
            prompt = "Create a summary for this exchange:\nUser: \(cappedUser)\nAssistant: \(cappedResponse)"
        } else {
            prompt = "Current summary: \(cappedExisting)\n\nNew exchange:\nUser: \(cappedUser)\nAssistant: \(cappedResponse)\n\nUpdate the summary."
        }

        do {
            let result = try await session.respond(to: prompt)
            let summary = result.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return String(summary.prefix(TokenBudget.conversationContextCap))
        } catch {
            return existing
        }
    }

    // MARK: - Utility Sessions

    struct GreetingResult {
        var headline: String
        var subtitle: String
    }

    @Generable
    struct GeneratedGreeting {
        @Guide(description: "Short greeting like 'Hi Adam' or 'Good evening'. 2-4 words max. MUST NOT be a question.")
        var headline: String

        @Guide(description: "Friendly, neutral statement like 'Ready when you are.' or 'Let's get started.' One short sentence. MUST NOT be a question. MUST NOT end with a question mark.")
        var subtitle: String
    }

    func generateGreeting(userName: String?) async -> GreetingResult {
        let session = LanguageModelSession(
            instructions: "You generate greeting text for a chat app. NEVER ask a question. NEVER use a question mark. Output a short greeting and a friendly neutral statement."
        )

        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = hour < 12 ? "morning" : (hour < 17 ? "afternoon" : "evening")

        let nameStr = (userName?.isEmpty == false) ? userName! : "there"

        let prompt = "Generate a greeting for \(nameStr) in the \(timeOfDay). The headline should be a short greeting with their name like 'Hey \(nameStr)' or 'Good \(timeOfDay), \(nameStr)'. The subtitle should be a friendly, upbeat, neutral statement — NOT a question. Examples of good subtitles: 'Ready for whatever you need.', 'Let's see what we can get into.', 'Here whenever you need me.'"

        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedGreeting.self
            )
            return GreetingResult(
                headline: response.content.headline.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: response.content.subtitle
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "?", with: ".")
            )
        } catch {
            let fallbackHeadline: String
            switch timeOfDay {
            case "morning": fallbackHeadline = "Good morning, \(nameStr)!"
            case "afternoon": fallbackHeadline = "Good afternoon, \(nameStr)!"
            default: fallbackHeadline = "Good evening, \(nameStr)!"
            }
            return GreetingResult(headline: fallbackHeadline, subtitle: "Ready for whatever you need.")
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
