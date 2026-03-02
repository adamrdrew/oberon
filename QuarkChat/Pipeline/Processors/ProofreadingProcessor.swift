import Foundation
import FoundationModels

struct ProofreadingProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        let textToProofread = extractText(from: query)
        guard !textToProofread.isEmpty else { return .empty }

        do {
            let session = LanguageModelSession(
                instructions: "Proofread the given text. Fix grammar, spelling, and punctuation. Return the corrected text and a list of corrections made."
            )

            let response = try await session.respond(
                to: textToProofread,
                generating: ProofreadResult.self
            )

            let result = response.content
            let correctedText = result.correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
            let corrections = result.corrections.trimmingCharacters(in: .whitespacesAndNewlines)

            let copyAction = RichAction(
                type: .copyToClipboard,
                label: "Copy Corrected Text",
                subtitle: String(correctedText.prefix(50)),
                payload: ["text": correctedText]
            )

            var enrichment = "Corrected text: \(correctedText)"
            if !corrections.isEmpty {
                enrichment += "\n\nCorrections: \(corrections)"
            }

            return DomainResult(
                enrichmentText: enrichment,
                citations: [],
                actions: [copyAction],
                richContent: [],
                suggestedReplies: SuggestedReply.forProofreading()
            )
        } catch {
            return .empty
        }
    }

    private func extractText(from query: String) -> String {
        var text = query
        let prefixes = [
            "proofread this: ", "proofread: ", "proofread ",
            "proof read this: ", "proof read: ", "proof read ",
            "check my grammar: ", "check my grammar in: ", "check my grammar ",
            "fix my grammar: ", "fix my grammar in: ", "fix my grammar ",
            "grammar check: ", "grammar check ",
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
