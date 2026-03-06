import Foundation

struct SuggestedReply: Codable, Identifiable, Sendable {
    let id: UUID
    let text: String

    init(text: String) {
        self.id = UUID()
        self.text = text
    }
}

// MARK: - Factory Methods

extension SuggestedReply {

    static func forWebSearch() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Tell me more"),
            SuggestedReply(text: "Related topics?"),
        ]
    }

    static func forImageSearch() -> [SuggestedReply] {
        [
            SuggestedReply(text: "More images"),
            SuggestedReply(text: "Tell me about this"),
        ]
    }

    static func forVideoSearch() -> [SuggestedReply] {
        [
            SuggestedReply(text: "More videos"),
            SuggestedReply(text: "Tell me about this"),
        ]
    }

    static func forURLReader() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Summarize the key points"),
            SuggestedReply(text: "What else is interesting here?"),
        ]
    }

    static func forWikipedia() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Tell me more"),
            SuggestedReply(text: "Related topics?"),
        ]
    }
}
