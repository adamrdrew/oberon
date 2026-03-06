# Oberon

A private, on-device AI chatbot for Apple platforms. All inference runs locally — no data leaves your device.

## Features

- **Dual AI backends** — Apple Foundation Models (zero-download, built into Apple Intelligence) or MLX Qwen3-4B (2.3 GB download, more capable reasoning)
- **Tool calling** — Web search, image search, video search, URL reading, and Wikipedia lookup. The model decides when to use tools autonomously.
- **Rich results** — Citations, link previews, image grids, video lists, Wikipedia cards, and suggested follow-up replies
- **Liquid Glass design** — Native iOS/iPadOS/macOS 26+ UI with glass effects throughout
- **Conversation sync** — SwiftData + CloudKit syncs conversations across devices
- **On-device memory** — Stores your name, location, and preferences locally (never synced)
- **6 color themes** — Named after moons of Uranus: Oberon, Titania, Ariel, Miranda, Puck, Umbriel
- **Streaming responses** — Real-time token streaming with typing indicators and pipeline status
- **Thinking indicator** — Visual feedback when the MLX backend is reasoning (Qwen3 thinking mode)

## Requirements

- iOS 26.2+ / iPadOS 26.2+ / macOS 26.2+
- Apple Silicon (required for MLX backend)
- Apple Intelligence enabled (required for Foundation Models backend)
- Metal Toolchain for building: `xcodebuild -downloadComponent MetalToolchain`

## Architecture

**MVVM with @Observable** — Views → ViewModels → Services → Model Backends

| Component | Role |
|-----------|------|
| `ChatBackend` protocol | Abstraction for model backends |
| `FoundationModelBackend` | Apple Intelligence — 4K context, 4 tools, transcript compaction |
| `MLXBackend` | Qwen3-4B — 32K context, 5 tools, thinking mode, `ChatSession` |
| `ChatService` | Router delegating to the active backend |
| `ToolResultStore` | Actor bridging tool returns with rich UI metadata |
| `ToolRegistry` | Actor mapping tool names to executor closures (MLX) |

### Tools

| Tool | Backends | Description |
|------|----------|-------------|
| `web_search` | Both | DuckDuckGo search with parallel page extraction (SwiftSoup + Reductio) |
| `image_search` | Both | DuckDuckGo image search |
| `video_search` | Both | DuckDuckGo video search |
| `read_url` | Both | Fetches and extracts content from a URL |
| `wikipedia` | MLX only | Wikipedia REST API with rich article cards |

## Building

```bash
# iOS Simulator
xcodebuild -project QuarkChat.xcodeproj -scheme QuarkChat \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# macOS
xcodebuild -project QuarkChat.xcodeproj -scheme QuarkChat \
  -destination 'platform=macOS' build

# Run tests
xcodebuild test -project QuarkChat.xcodeproj -scheme QuarkChat \
  -destination 'platform=macOS'
```

Or open `QuarkChat.xcodeproj` in Xcode 26+ and build directly.

## Dependencies

| Package | Purpose |
|---------|---------|
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) | Markdown rendering in chat bubbles |
| [SwiftSoup](https://github.com/scinfu/SwiftSoup) | HTML parsing for search results and page extraction |
| [Reductio](https://github.com/fdzsergio/Reductio) | TextRank extractive summarization |
| [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-examples) | On-device MLX inference (Qwen3-4B) |

## Privacy

Everything runs on-device. No API keys, no cloud inference, no telemetry. Conversations sync via CloudKit only if iCloud is enabled. User profile data (name, preferences) is stored locally and never synced.
