# Oberon — Development Guide

## What Is This

Oberon is an on-device, private AI chatbot using Apple Foundation Models (iOS/macOS/iPadOS 26+). Liquid Glass design. 2-pane layout. SwiftData + CloudKit sync.

## Before Writing Any Code

1. **Consult `references/`** — 37 files of Foundation Models, Liquid Glass, animation, and SwiftData+CloudKit documentation
2. **Consult `.claude/skills/`** — Architecture, Foundation Models patterns, SwiftData models, Chat UI, Tool implementation, Error handling
3. **Check memory** — `.claude/projects/.../memory/MEMORY.md` has key technical facts

## Critical Constraints

- **Foundation Model context: 4,096 tokens total** (instructions + tools + messages + response)
- **Max 3-5 tools per session** — tool definitions eat context tokens
- **Model can't do**: math, code generation, complex reasoning — supplement with tools
- **CloudKit models**: no @Attribute(.unique), all props optional/defaulted, relationships optional, no .deny delete rule
- **Transcript is Codable** but restoring long transcripts will exceed context — trim first

## Code Style

- **SwiftUI** with `@Observable` (not ObservableObject)
- **Liquid Glass** everywhere — `.glassEffect()`, `GlassEffectContainer`, `.buttonStyle(.glass)`
- **NavigationSplitView** for 2-pane layout
- Keep views thin — logic in `@Observable` view models
- Platform conditionals with `#if os(macOS)` / `#if os(iOS)`
- Minimum deployment: iOS 26.0, macOS 26.0, iPadOS 26.0

## File Organization

See `.claude/skills/architecture/SKILL.md` for full file tree.

## Testing

- Test on physical devices for Foundation Models (Simulator has limited support)
- CloudKit sync requires real device with iCloud account
- Use Instruments with Foundation Models instrument for token profiling
