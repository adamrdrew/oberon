import Foundation
import FoundationModels

struct RewritingProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        let textToRewrite = extractText(from: query)
        guard !textToRewrite.isEmpty else { return .empty }

        do {
            let session = LanguageModelSession(
                instructions: "Rewrite the given text to improve clarity, tone, and flow. Preserve the original meaning. Return ONLY the rewritten text."
            )

            let response = try await session.respond(to: textToRewrite)
            let rewritten = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            let copyAction = RichAction(
                type: .copyToClipboard,
                label: "Copy Rewritten Text",
                subtitle: String(rewritten.prefix(50)),
                payload: ["text": rewritten]
            )

            return DomainResult(
                enrichmentText: "Original: \(textToRewrite)\n\nRewritten: \(rewritten)",
                citations: [],
                actions: [copyAction],
                richContent: [],
                suggestedReplies: SuggestedReply.forRewriting()
            )
        } catch {
            return .empty
        }
    }

    private func extractText(from query: String) -> String {
        var text = query
        let prefixes = [
            "rewrite this: ", "rewrite: ", "rewrite ",
            "rephrase this: ", "rephrase: ", "rephrase ",
            "paraphrase this: ", "paraphrase: ", "paraphrase ",
            "reword this: ", "reword: ", "reword ",
        ]
        let lower = text.lowercased()
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
