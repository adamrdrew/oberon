# Chat UI — Liquid Glass Design

## Design Language

QuarkChat uses **Liquid Glass** throughout. All UI follows iOS/macOS 26+ idioms.

### Layout Structure

```
┌─────────────────────────────────────────────────┐
│  NavigationSplitView                            │
│ ┌──────────┐┌──────────────────────────────────┐│
│ │ Sidebar  ││ Detail (ChatView)                ││
│ │          ││                                  ││
│ │ Conv 1   ││  ┌─────────────────────────┐     ││
│ │ Conv 2 ← ││  │ Message bubble (user)   │     ││
│ │ Conv 3   ││  └─────────────────────────┘     ││
│ │          ││  ┌─────────────────────────┐     ││
│ │          ││  │ Message bubble (asst)   │     ││
│ │          ││  │ with glass effect       │     ││
│ │          ││  └─────────────────────────┘     ││
│ │          ││  ┌─── ToolUseIndicator ────┐     ││
│ │          ││  │ 🔍 Searching web...     │     ││
│ │          ││  └─────────────────────────┘     ││
│ │          ││  ┌─── TypingIndicator ─────┐     ││
│ │          ││  │ ● ● ●                   │     ││
│ │          ││  └─────────────────────────┘     ││
│ │          ││                                  ││
│ │ [+ New]  ││  ┌──────────────────────────────┐││
│ │          ││  │ MessageInputBar (glass)       │││
│ │          ││  │ [TextField        ] [Send ▶]  │││
│ │          ││  └──────────────────────────────┘││
│ └──────────┘└──────────────────────────────────┘│
└─────────────────────────────────────────────────┘
```

### Sidebar

```swift
NavigationSplitView {
    ConversationListView()
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        #endif
} detail: {
    if let conversation = selectedConversation {
        ChatView(conversation: conversation)
    } else {
        ContentUnavailableView("No Chat Selected",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Select or start a conversation"))
    }
}
```

### Message Bubbles

User messages: right-aligned, tinted glass.
Assistant messages: left-aligned, regular glass.

```swift
struct MessageBubble: View {
    let message: Message

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(
                    isUser
                        ? .regular.tint(.blue)
                        : .regular,
                    in: .rect(cornerRadius: 18)
                )

            if !isUser { Spacer(minLength: 60) }
        }
    }
}
```

### Streaming Message Display

During streaming, show partial text with a cursor/blinking indicator:

```swift
struct StreamingMessageView: View {
    let text: String
    @State private var showCursor = true

    var body: some View {
        HStack {
            (Text(text) + Text(showCursor ? "▍" : " ").foregroundStyle(.secondary))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(in: .rect(cornerRadius: 18))
            Spacer(minLength: 60)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                showCursor.toggle()
            }
        }
    }
}
```

### Typing Indicator

Animated bouncing dots shown while `session.isResponding` is true and before first token arrives:

```swift
struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 8, height: 8)
                    .offset(y: sin(phase + Double(index) * 0.8) * 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 18))
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
```

### Tool Use Indicator

Shows the tool name and a brief status while a tool is executing:

```swift
struct ToolUseIndicator: View {
    let toolName: String

    var displayText: String {
        switch toolName {
        case "web_search": return "Searching the web…"
        default: return "Working…"
        }
    }

    var displayIcon: String {
        switch toolName {
        case "web_search": return "magnifyingglass"
        default: return "gearshape"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: displayIcon)
                .symbolEffect(.pulse)
            Text(displayText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(.orange), in: .rect(cornerRadius: 12))
    }
}
```

### Message Input Bar

Glass input bar pinned to the bottom:

```swift
struct MessageInputBar: View {
    @Binding var text: String
    let isGenerating: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .onSubmit { if !text.isEmpty && !isGenerating { onSend() } }

            Button {
                isGenerating ? onStop() : onSend()
            } label: {
                Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .symbolEffect(.bounce, value: isGenerating)
            }
            .disabled(text.isEmpty && !isGenerating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 22))
        .padding()
    }
}
```

### Scroll Behavior

Auto-scroll to bottom on new messages. Use `ScrollViewReader`:

```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack(spacing: 12) {
            ForEach(messages) { message in
                MessageBubble(message: message)
                    .id(message.id)
            }
            if isStreaming {
                StreamingMessageView(text: streamText)
                    .id("streaming")
            }
        }
        .padding()
    }
    .onChange(of: messages.count) { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
    .onChange(of: streamText) { proxy.scrollTo("streaming", anchor: .bottom) }
}
```

### Glass Button Styles

Use `.buttonStyle(.glass)` for standard actions and `.buttonStyle(.glassProminent)` for primary actions. For the new conversation button:

```swift
Button {
    createNewConversation()
} label: {
    Label("New Chat", systemImage: "plus.bubble")
}
.buttonStyle(.glass)
```

### Animation Guidelines

- Use `withAnimation(.spring(response: 0.35, dampingFraction: 0.8))` for UI state changes
- Use `.symbolEffect()` for SF Symbol animations — NOT `withAnimation`
- Wrap glass containers in `GlassEffectContainer` when multiple glass views are adjacent
- Support reduced motion: check `@Environment(\.accessibilityReduceMotion)`
