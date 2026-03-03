# SwiftData Models — Oberon

## CloudKit Constraints — MUST FOLLOW

All models synced via CloudKit MUST obey these rules:
1. **No `@Attribute(.unique)`** — CloudKit doesn't support unique constraints
2. **All properties must be optional OR have default values**
3. **All relationships must be optional**
4. **Inverse relationships required** on both sides
5. **No `.deny` delete rule** — use `.nullify` (default) or `.cascade`
6. **No ordered relationships**
7. **Schema is additive-only** after first CloudKit deployment — no renames, no deletes, no type changes

## Core Models

### Conversation

```swift
import SwiftData
import Foundation

@Model
final class Conversation {
    var id: UUID = UUID()
    var title: String = "New Chat"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]? = []

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

### Message

```swift
@Model
final class Message {
    var id: UUID = UUID()
    var content: String = ""
    var role: String = "user"          // "user", "assistant", "system"
    var createdAt: Date = Date()
    var isComplete: Bool = true        // false during streaming

    // Tool use tracking
    var toolName: String?              // nil if no tool was used
    var toolInput: String?             // JSON of tool arguments
    var toolOutput: String?            // Result from tool

    var conversation: Conversation?

    init(content: String, role: String, conversation: Conversation? = nil) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.createdAt = Date()
        self.isComplete = true
        self.conversation = conversation
    }
}
```

### UserProfile (Local Only — Not Synced)

```swift
@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String?
    var aboutMe: String?               // Free text: things the user wants the AI to know
    var preferences: String?           // JSON string for flexible key-value prefs
    var updatedAt: Date = Date()

    init() {
        self.id = UUID()
        self.updatedAt = Date()
    }
}
```

## ModelContainer Setup

```swift
// Synced configuration (Conversation, Message)
let syncedConfig = ModelConfiguration(
    "Oberon",
    schema: Schema([Conversation.self, Message.self]),
    cloudKitDatabase: .automatic
)

// Local-only configuration (UserProfile)
let localConfig = ModelConfiguration(
    "OberonLocal",
    schema: Schema([UserProfile.self]),
    cloudKitDatabase: .none
)

let container = try ModelContainer(
    for: Conversation.self, Message.self, UserProfile.self,
    configurations: syncedConfig, localConfig
)
```

## Query Patterns

### Conversation List (sorted by most recent)
```swift
@Query(sort: \Conversation.updatedAt, order: .reverse)
private var conversations: [Conversation]
```

### Messages for a Conversation (chronological)
```swift
// In a view that has the conversation
let messages = conversation.messages?.sorted(by: { $0.createdAt < $1.createdAt }) ?? []
```

### Dynamic Filtering
```swift
@Query(filter: #Predicate<Conversation> { $0.title.contains(searchText) })
```

## Background Operations

Use `@ModelActor` for any writes that shouldn't block UI:

```swift
@ModelActor
actor ChatPersistenceActor {
    func saveMessage(content: String, role: String, conversationID: PersistentIdentifier) {
        guard let conversation = self[conversationID, as: Conversation.self] else { return }
        let message = Message(content: content, role: role, conversation: conversation)
        modelContext.insert(message)
        conversation.updatedAt = Date()
        try? modelContext.save()
    }
}
```

**Threading rules:**
- Only `PersistentIdentifier` and `ModelContainer` are `Sendable`
- Never pass `@Model` objects between actors
- Fetch by ID on the target actor

## Schema Evolution

After first CloudKit deployment, only ADD properties with defaults:
```swift
// OK: Adding a new optional property
var summary: String?

// OK: Adding with default
var isPinned: Bool = false

// FORBIDDEN: Removing, renaming, or changing types
```
