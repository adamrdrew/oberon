import Foundation
import FoundationModels

enum TokenBudget {
    // MARK: - Context Size

    /// The Foundation Models context window size, queried from the model at runtime.
    /// Back-deployed to 26.0 via @backDeployed.
    static var foundationModelContextSize: Int {
        SystemLanguageModel.default.contextSize
    }

    // MARK: - Compaction

    /// Foundation Models: compact at ~68% of context to leave room for response + new prompt.
    static var compactionThreshold: Int {
        Int(Double(foundationModelContextSize) * 0.68)
    }
    static let mlxBalancedCompactionThreshold = 8000 // Qwen3-1.7B: 32K context, compact earlier for quality
    static let mlxCompactionThreshold = 16000 // Qwen3-4B: 32K context, compact at ~50%

    // MARK: - Token Counting

    /// Returns exact token count for instructions on 26.4+, falls back to estimation.
    static func tokenCount(for instructions: String) async -> Int {
        if #available(iOS 26.4, macOS 26.4, *) {
            let model = SystemLanguageModel.default
            if let count = try? await model.tokenCount(for: Instructions(instructions)) {
                return count
            }
        }
        return estimateTokens(instructions)
    }

    // MARK: - Token Estimation

    static func estimateTokens(_ text: String) -> Int {
        text.count / 4
    }

    static func estimateTokens(for transcript: Transcript) -> Int {
        var total = 0
        for entry in transcript {
            switch entry {
            case .instructions(let instr):
                for segment in instr.segments {
                    if case .text(let t) = segment {
                        total += t.content.count / 4
                    }
                }
            case .prompt(let p):
                for segment in p.segments {
                    if case .text(let t) = segment {
                        total += t.content.count / 4
                    }
                }
            case .response(let r):
                for segment in r.segments {
                    if case .text(let t) = segment {
                        total += t.content.count / 4
                    }
                }
            default:
                total += 50 // rough estimate for tool calls/output
            }
        }
        return total
    }
}
