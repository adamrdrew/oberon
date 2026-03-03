# Foundation Models Integration

## Session Lifecycle

**ALWAYS consult `references/` docs before making Foundation Model changes.**

### Creating a Session

```swift
import FoundationModels

let model = SystemLanguageModel.default

// Check availability FIRST
guard model.isAvailable else {
    // Show unavailability UI
    return
}

let session = LanguageModelSession(
    model: model,
    tools: [WebSearchTool()],
    instructions: instructions
)
```

### System Instructions Pattern

Instructions are the MOST reliable way to steer behavior. Keep them concise (1-3 paragraphs). The model prioritizes instructions over prompts.

```swift
let instructions = Instructions {
    """
    You are Oberon, a helpful AI assistant running on-device. \
    You are honest about your limitations. When you don't know something, \
    use the web_search tool to find current information. \
    Keep responses concise and helpful.
    """
    if let userName = userProfile?.name {
        "The user's name is \(userName)."
    }
    if let userContext = userProfile?.aboutMe {
        "About the user: \(userContext)"
    }
}
```

**NEVER put user input in Instructions** — prompt injection risk. User messages go in Prompt only.

### Streaming Responses (Primary Pattern)

Always prefer streaming for chat UX:

```swift
func streamResponse(to userMessage: String) async throws {
    isGenerating = true
    defer { isGenerating = false }

    let stream = session.streamResponse(to: userMessage)

    for try await snapshot in stream {
        // Update UI with partial content
        currentStreamText = snapshot.content
    }

    // Collect final response
    let response = try await stream.collect()
    let finalText = response.content
}
```

### Prewarming

Call `prewarm()` when a conversation is opened, before the user sends a message:

```swift
session.prewarm(promptPrefix: "You are a helpful assistant")
```

### Context Window Management — CRITICAL

**Total context: 4,096 tokens** — instructions + tools + all messages + response.

This is VERY small. Strategies:
1. Keep instructions minimal
2. Tool descriptions must be short
3. For long conversations, create a NEW session with a summary of prior context
4. Monitor `session.transcript` size
5. Use `model.tokenCount(for:)` to check before sending

### Transcript Persistence

Transcript is `Codable` — serialize to restore conversations:

```swift
// Save
let data = try JSONEncoder().encode(session.transcript)

// Restore
let transcript = try JSONDecoder().decode(Transcript.self, from: data)
let restoredSession = LanguageModelSession(
    model: model,
    tools: tools,
    transcript: transcript
)
```

**BUT** — due to 4096 token limit, restoring full transcripts for long conversations will exceed context. Instead, store messages in SwiftData and reconstruct a trimmed transcript when resuming.

### Generation Options

```swift
let options = GenerationOptions(
    sampling: .greedy,              // Deterministic, best for factual
    temperature: 0.7,              // Higher = more creative
    maximumResponseTokens: 1024    // Don't set too low — causes malformed output
)
```

Sampling modes:
- `.greedy` — Most likely token, deterministic. Use for factual/tool responses.
- `.random(top: k, seed:)` — Top-k sampling. Use for creative responses.

### Model Limitations — Design Around These

The model **cannot reliably**:
- Do math
- Generate code
- Perform complex logical reasoning
- Handle very long context

**Always** supplement with tools for factual accuracy. The model is good at:
- Natural language understanding
- Text summarization
- Creative writing (short form)
- Following structured output schemas
- Deciding when to call tools
