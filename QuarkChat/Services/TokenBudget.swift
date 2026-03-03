import Foundation
import FoundationModels

enum TokenBudget {
    // MARK: - Compaction

    static let compactionThreshold = 2800  // estimated tokens before compaction

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
