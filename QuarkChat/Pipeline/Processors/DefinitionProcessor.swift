import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct DefinitionProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        let word = extractWord(from: query)
        guard !word.isEmpty else { return .empty }

        // Build a "Look Up" action
        let lookUpAction = RichAction(
            type: .openApp,
            label: "Look Up",
            subtitle: word,
            payload: ["word": word]
        )

        // We provide enrichment text telling the LLM to define the word
        // The Foundation Model is decent at definitions for common words
        let enrichmentText = "Define the word: \"\(word)\". Provide the definition, part of speech, and a brief example sentence."

        return DomainResult(
            enrichmentText: enrichmentText,
            citations: [],
            actions: [lookUpAction],
            richContent: [],
            suggestedReplies: SuggestedReply.forDefinition()
        )
    }

    private func extractWord(from query: String) -> String {
        var text = query.lowercased()

        let prefixes = [
            "define the word ",
            "define ",
            "definition of the word ",
            "definition of ",
            "meaning of the word ",
            "meaning of ",
            "what does the word ",
            "what does ",
            "what is the meaning of ",
        ]

        for prefix in prefixes {
            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        // Strip trailing " mean" or " mean?"
        let suffixes = [" mean?", " mean"]
        for suffix in suffixes {
            if text.hasSuffix(suffix) {
                text = String(text.dropLast(suffix.count))
                break
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
}
