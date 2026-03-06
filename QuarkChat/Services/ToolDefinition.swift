import Foundation

/// Backend-agnostic tool schema used by MLX to build system prompt tool blocks.
/// Foundation Models backend ignores these (it uses actual `[any Tool]` objects).
struct ToolDefinition: Sendable, Codable {
    let name: String
    let description: String
    let parameters: [ToolParameter]

    struct ToolParameter: Sendable, Codable {
        let name: String
        let type: String // "string", "integer", etc.
        let description: String
        let required: Bool
    }
}
