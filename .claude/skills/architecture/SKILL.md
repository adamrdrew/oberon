# Oberon Architecture

## App Structure

Oberon uses **MVVM with @Observable** pattern. All view models are `@Observable` classes. Views are thin — logic lives in view models and services.

### File Organization

```
QuarkChat/
├── App/
│   ├── OberonApp.swift             # @main, ModelContainer setup
│   └── AppState.swift              # Global app state (@Observable)
├── Models/                         # SwiftData @Model classes
│   ├── Conversation.swift
│   ├── Message.swift
│   └── UserProfile.swift
├── ViewModels/
│   ├── ChatViewModel.swift         # Active chat session management
│   ├── ConversationListViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── Chat/
│   │   ├── ChatView.swift          # Main chat pane
│   │   ├── MessageBubble.swift     # Individual message display
│   │   ├── MessageInputBar.swift   # Text input + send button
│   │   ├── TypingIndicator.swift   # Animated dots during generation
│   │   └── ToolUseIndicator.swift  # Shows when tool is being called
│   ├── Sidebar/
│   │   ├── ConversationListView.swift
│   │   └── ConversationRow.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Components/                 # Reusable UI pieces
│       └── ...
├── Services/
│   ├── ChatService.swift           # Foundation Model session management
│   ├── WebSearchService.swift      # DuckDuckGo search implementation
│   └── UserProfileService.swift    # On-device memory/preferences
├── Tools/                          # Foundation Model Tool conformances
│   ├── WebSearchTool.swift
│   └── ...
└── Utilities/
    └── ...
```

### Dependency Flow

```
Views → ViewModels → Services → Foundation Models / SwiftData
                              → Tools (called by Foundation Models)
```

### Key Patterns

**@Observable ViewModels** — Not ObservableObject. Use `@Observable` (iOS 17+):
```swift
@Observable
final class ChatViewModel {
    var messages: [Message] = []
    var isGenerating = false
    var currentStreamText = ""

    private let chatService: ChatService
    private let modelContext: ModelContext
}
```

**View owns ViewModel via @State**:
```swift
struct ChatView: View {
    @State private var viewModel: ChatViewModel

    init(conversation: Conversation, modelContext: ModelContext) {
        _viewModel = State(initialValue: ChatViewModel(
            conversation: conversation,
            modelContext: modelContext
        ))
    }
}
```

**Services are long-lived** — injected via environment or passed to view models. `ChatService` wraps `LanguageModelSession` and manages the Foundation Model lifecycle.

**ModelContext threading** — Main actor for UI reads. `@ModelActor` for background writes. Only pass `PersistentIdentifier` between actors, never model objects.

### Platform Adaptation

Target all three platforms with one codebase using conditional compilation:
```swift
#if os(macOS)
    .navigationSplitViewColumnWidth(min: 220, ideal: 260)
#endif
```

Use `NavigationSplitView` for the 2-pane layout — it adapts automatically across iOS (sidebar overlay), iPadOS (side-by-side), and macOS (fixed sidebar).

### State Management

- **AppState** — Global: model availability, current user profile
- **ChatViewModel** — Per-conversation: messages, generation state, streaming text
- **ConversationListViewModel** — Sidebar: conversation list, search, new/delete
- **SwiftData @Query** — Preferred for list views that just display data
- **ViewModel** — Preferred when complex logic is needed (chat interaction)
