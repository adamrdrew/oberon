import Foundation

struct ClipboardProcessor: Sendable {

    func process(query: String, lastAssistantMessage: String?) async -> DomainResult {
        let textToCopy: String

        if let lastMessage = lastAssistantMessage, !lastMessage.isEmpty {
            textToCopy = lastMessage
        } else {
            textToCopy = ""
        }

        guard !textToCopy.isEmpty else {
            return DomainResult(
                enrichmentText: "There's nothing to copy — no previous response found.",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }

        let action = RichAction(
            type: .copyToClipboard,
            label: "Copy to Clipboard",
            subtitle: String(textToCopy.prefix(50)) + (textToCopy.count > 50 ? "..." : ""),
            payload: ["text": textToCopy]
        )

        return DomainResult(
            enrichmentText: "Copied to clipboard.",
            citations: [],
            actions: [action],
            richContent: [],
            suggestedReplies: []
        )
    }
}
