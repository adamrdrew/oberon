import Foundation

/// Strips `<think>...</think>` reasoning blocks from streamed Qwen3 output
/// so they don't appear in the chat UI.
///
/// Note: `<tool_call>` parsing is handled by MLX's ChatSession internally
/// via ToolCallFormat.json — we don't need to parse those ourselves.
enum MLXToolCallParser {

    /// Remove all `<think>...</think>` blocks from text (including partial).
    static func stripThinkingBlocks(_ text: String) -> String {
        // Full blocks: <think>...</think>
        var result = text
        let fullPattern = #"<think>[\s\S]*?</think>\s*"#
        if let regex = try? NSRegularExpression(pattern: fullPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Partial trailing block: <think>... (no closing tag yet)
        let partialPattern = #"<think>[\s\S]*$"#
        if let regex = try? NSRegularExpression(pattern: partialPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if text is currently inside a `<think>` block (streaming context).
    static func isInsideThinkBlock(_ text: String) -> Bool {
        let openCount = text.components(separatedBy: "<think>").count - 1
        let closeCount = text.components(separatedBy: "</think>").count - 1
        return openCount > closeCount
    }
}
