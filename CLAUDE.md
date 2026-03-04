# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Is This

Oberon is an on-device, private AI chatbot using Apple Foundation Models (iOS/macOS/iPadOS 26+). Liquid Glass design. 2-pane NavigationSplitView layout. SwiftData + CloudKit sync.

## Before Writing Any Code

1. **Consult `references/`** — 37 files of Foundation Models, Liquid Glass, animation, and SwiftData+CloudKit documentation
2. **Consult `.claude/skills/`** — Architecture, Foundation Models patterns, SwiftData models, Chat UI, Tool implementation, Error handling
3. **Check memory** — `.claude/projects/.../memory/MEMORY.md` has key technical facts

## Build & Run

This is an Xcode project (no Package.swift). Build from Xcode or command line:

```bash
# Build for iOS Simulator
xcodebuild -project QuarkChat.xcodeproj -scheme QuarkChat -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Build for macOS
xcodebuild -project QuarkChat.xcodeproj -scheme QuarkChat -destination 'platform=macOS' build
```

**No test targets exist.** Foundation Models require physical device testing (Simulator has limited support). CloudKit sync requires real device with iCloud account. Use Instruments with Foundation Models instrument for token profiling.

## Critical Constraints

- **Foundation Model context: 4,096 tokens total** (instructions + tools + messages + response)
- **Max 3-5 tools per session** — tool definitions eat context tokens; we use 4 (DateTimeTool exists but is not registered)
- **Model can't do**: math, code generation, complex reasoning — supplement with tools
- **CloudKit models**: no `@Attribute(.unique)`, all props optional/defaulted, relationships optional, no `.deny` delete rule
- **Transcript is Codable** but restoring long transcripts will exceed context — trim first

## Architecture

**MVVM with @Observable** — Views → ViewModels → Services → Foundation Models / SwiftData / Tools

**Dual ModelContainer** (in `OberonApp.swift`):
- Synced config: `Conversation` + `Message` (CloudKit `.automatic`)
- Local config: `UserProfile` (CloudKit `.none`)

**Native tool calling** — `LanguageModelSession` with 6 registered tools. Model decides when to invoke. `ToolResultStore` (actor) bridges tool returns with rich UI metadata (citations, actions, richContent, suggestedReplies, pipelineSteps). `ChatViewModel` drains after each response.

**Persistent session** — Reuses `LanguageModelSession` across turns per conversation. Transcript serialized to `Conversation.transcriptData`. Compaction triggers at ~2,800 estimated tokens (summarizes old turns, rebuilds session).

**Deferred conversation creation** — `Conversation()` created as transient object until first message, then inserted into SwiftData. Prevents empty sidebar entries.

## Concurrency Rules (Critical — Learned from Release Deadlock Bugs)

- **`streamResponse` must NOT be `@MainActor`** — use `MainActor.run` only for UI property updates
- **Never call `stream.collect()` after iterating a `ResponseStream`** — hangs in Release builds
- **Data model structs used in Tool `call()` must be `nonisolated`** — tools run on background threads; MainActor hop while MainActor is busy → deadlock
- **`OTheme` static vars are `@MainActor`** — any type with computed properties accessing OTheme gets infected; keep OTheme references out of model types
- **Polling tasks must use `Task.detached`** — `Task { }` inside `@MainActor` class inherits MainActor, causing contention with streaming
- **Debug vs Release**: actor scheduling differs; deadlocks may only appear in Release/Archive builds

## Build Settings of Note

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — everything is MainActor by default
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- Deployment targets: iOS 26.2, macOS 26.2, iPadOS 26.2

## Code Style

- **SwiftUI** with `@Observable` (not ObservableObject)
- **Liquid Glass** everywhere — `.glassEffect()`, `GlassEffectContainer`, `.buttonStyle(.glass)`
- **NavigationSplitView** for 2-pane layout
- Keep views thin — logic in `@Observable` view models
- Platform conditionals with `#if os(macOS)` / `#if os(iOS)`

## API Gotchas

- `.glassEffect()` tint: `.glassEffect(.regular.tint(.blue), in: .rect(cornerRadius: 16))`
- `Transcript.ToolCall` has `.toolName` (not `.tool.name`)
- `LanguageModelSession(model:tools:transcript:)` does NOT accept `instructions:` — instructions come from the transcript
- `LanguageModelSession(model:tools:instructions:)` for fresh sessions
- Transcript entry constructors require `id:` parameter: `.instructions(.init(id:segments:toolDefinitions:))`, `.prompt(.init(id:segments:))`, `.response(.init(id:assetIDs:segments:))`

## Dependencies (SPM via Xcode)

| Package | Version | Purpose |
|---------|---------|---------|
| MarkdownUI | 2.4.1 | Markdown rendering in chat bubbles |
| SwiftSoup | 2.11.3 | HTML parsing (DDG results + page extraction) |
| Reductio | 1.7.0 | TextRank extractive summarization (`text.summarize(count: N)` returns `[String]`) |

## Theme System

6 themes named after moons of Uranus: Oberon (default), Titania, Ariel, Miranda, Puck, Umbriel. `ColorTheme` struct → `ThemeManager` @Observable singleton → `OTheme` computed static vars. Views use `OTheme.accent` etc. — zero call-site changes when switching themes. Persistence via `UserProfile.themeID`.

## File Organization

See `.claude/skills/architecture/SKILL.md` for full file tree.
