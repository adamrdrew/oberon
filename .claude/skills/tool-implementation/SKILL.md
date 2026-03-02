# Foundation Model Tool Implementation

## Tool Design Principles

- **3-5 tools max** per session (hard framework constraint)
- Tool descriptions consume context tokens — keep SHORT
- Tool argument descriptions: 3-10 words max
- Return **strings** from tools — the model consumes the output as text
- Tools are `Sendable` — must be safe for concurrent execution
- Use `@Generable` for tool arguments

## Tool Protocol

```swift
struct MyTool: Tool {
    let name = "my_tool"
    let description = "Brief description of what it does"

    @Generable
    struct Arguments {
        @Guide(description: "Brief arg description")
        var argName: String
    }

    func call(arguments: Arguments) async throws -> String {
        // Do work, return string result
    }
}
```

## Planned Tools

### 1. Web Search (Confirmed)

```swift
struct WebSearchTool: Tool {
    let name = "web_search"
    let description = "Search the web for current information"

    @Generable
    struct Arguments {
        @Guide(description: "Search query")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        // Use DuckDuckGo HTML search or API
        // Parse results
        // Return formatted snippets as a string
    }
}
```

**Implementation notes:**
- DuckDuckGo has no official API requiring auth — use `https://html.duckduckgo.com/html/?q=`
- Parse HTML response for result snippets
- Return top 3-5 results as formatted text
- Keep response concise — every token of tool output eats context
- Consider caching recent searches

### 2. User Memory (Planned)

Lets the model read/write persistent facts about the user:

```swift
struct UserMemoryTool: Tool {
    let name = "user_memory"
    let description = "Read or save facts about the user"

    @Generable
    struct Arguments {
        @Guide(description: "read or write", .anyOf(["read", "write"]))
        var action: String
        @Guide(description: "Fact to remember")
        var fact: String?
    }

    func call(arguments: Arguments) async throws -> String {
        // Read: return stored user facts
        // Write: persist new fact to UserProfile
    }
}
```

### 3. Date/Time (Planned)

The model has no real-time clock access:

```swift
struct DateTimeTool: Tool {
    let name = "current_datetime"
    let description = "Get current date, time, and timezone"

    @Generable
    struct Arguments {
        // No arguments needed — but Tool protocol requires Generable args
        @Guide(description: "unused")
        var placeholder: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a zzz"
        return formatter.string(from: now)
    }
}
```

### Potential Additional Tools (Pick 1-2)

- **Calculator** — The model can't do math, so a simple expression evaluator could help
- **Contacts lookup** — Access address book (requires permission)
- **Calendar** — Read upcoming events (requires EventKit permission)
- **App actions** — Open URLs, create reminders, etc.

## Error Handling in Tools

Two strategies:
1. **Throw** — Escapes the entire generation. Use for unrecoverable errors.
2. **Return error string** — Lets the model try to handle gracefully. Preferred.

```swift
func call(arguments: Arguments) async throws -> String {
    do {
        let results = try await performSearch(arguments.query)
        return results
    } catch {
        // Return error as string so model can tell the user
        return "Search failed: \(error.localizedDescription). Please try rephrasing."
    }
}
```

## Tool Use Observation

Watch the transcript to detect tool calls for UI indicators:

```swift
// The session.transcript is @Observable
// Watch for .toolCalls entries to show ToolUseIndicator
// Watch for .toolOutput entries to hide it
```

## Context Budget Planning

With 4,096 tokens total, budget roughly:
- Instructions: ~300 tokens
- Tool definitions: ~200 tokens (keep descriptions very short!)
- Conversation history: ~2,500 tokens
- Tool output: ~500 tokens
- Response: ~500 tokens

This means conversations MUST be trimmed. Keep only the most recent N messages that fit within budget.
