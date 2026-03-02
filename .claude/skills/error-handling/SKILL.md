# Error Handling Patterns

## Foundation Model Errors

All errors from `LanguageModelSession.GenerationError`. Handle every case:

```swift
func handleGenerationError(_ error: Error) -> String {
    guard let genError = error as? LanguageModelSession.GenerationError else {
        return "Something went wrong. Please try again."
    }

    switch genError {
    case .guardrailViolation:
        return "I can't help with that kind of request. Try rephrasing?"

    case .refusal(let refusal, _):
        // Async — get the explanation
        // try? await refusal.explanation
        return "I'm not able to help with that."

    case .exceededContextWindowSize:
        // CRITICAL — must trim conversation and retry
        // Start new session with summary of prior context
        return "Our conversation is getting long. Let me start a fresh context."

    case .rateLimited:
        return "I need a moment. Please try again shortly."

    case .concurrentRequests:
        // Should not happen if UI disables input during generation
        return "I'm still working on your previous message."

    case .assetsUnavailable:
        return "The AI model isn't available right now. Check that Apple Intelligence is enabled."

    case .decodingFailure:
        // Structured generation failed — fall back to text
        return "I had trouble formatting my response. Let me try again."

    case .unsupportedGuide:
        // Development error — should not ship
        return "A configuration error occurred."

    case .unsupportedLanguageOrLocale:
        return "I don't support that language yet."

    @unknown default:
        return "Something unexpected happened. Please try again."
    }
}
```

## Context Window Overflow Strategy

This is the #1 error we'll hit in production. Strategy:

1. **Track token usage** — Use `model.tokenCount(for:)` before sending
2. **Trim proactively** — Before hitting the limit, summarize old messages
3. **Graceful degradation** — If we exceed, catch the error, create a new session with recent context
4. **Show UI feedback** — Let user know context was trimmed

```swift
func ensureContextFits(messages: [Message], session: LanguageModelSession) async throws -> LanguageModelSession {
    let model = SystemLanguageModel.default
    // Check if we're approaching the limit
    // If so, create new session with summary + recent messages
    // Return the new or existing session
}
```

## Model Availability

Check on app launch AND observe changes:

```swift
@Observable
final class AppState {
    var modelAvailability: SystemLanguageModel.Availability = .unavailable(.modelNotReady)

    func checkAvailability() {
        let model = SystemLanguageModel.default
        modelAvailability = model.availability
    }
}
```

Handle each case in UI:
- `.available` — Normal operation
- `.unavailable(.deviceNotEligible)` — Show permanent "not supported" message
- `.unavailable(.appleIntelligenceNotEnabled)` — Prompt to enable in Settings
- `.unavailable(.modelNotReady)` — Show loading/downloading state

## Tool Call Errors

`LanguageModelSession.ToolCallError` wraps tool failures:

```swift
do {
    let response = try await session.respond(to: prompt)
} catch let error as LanguageModelSession.ToolCallError {
    // error.tool — which tool failed
    // error.underlyingError — the actual error
    // The model may retry or inform the user depending on tool implementation
}
```

**Prefer returning error strings from tools** over throwing, so the model can handle gracefully.

## Network Errors (Web Search)

```swift
enum WebSearchError: LocalizedError {
    case networkUnavailable
    case parseFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "No internet connection"
        case .parseFailed: return "Could not parse search results"
        case .timeout: return "Search timed out"
        }
    }
}
```

In the tool, catch and return as string:
```swift
func call(arguments: Arguments) async throws -> String {
    guard NetworkMonitor.shared.isConnected else {
        return "No internet connection. I can only use my own knowledge right now."
    }
    // ...
}
```

## User-Facing Error Presentation

Never show raw error messages. Map to friendly messages and present inline in the chat as a system message — not as an alert:

```swift
struct ErrorMessageView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(.orange), in: .rect(cornerRadius: 12))
    }
}
```
