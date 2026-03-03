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

    static func forWeather() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Tomorrow's forecast?"),
            SuggestedReply(text: "This weekend?"),
            SuggestedReply(text: "Should I bring an umbrella?"),
        ]
    }

    static func forGeoSearch() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Get directions"),
            SuggestedReply(text: "Anything closer?"),
        ]
    }

    static func forWebSearch() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Tell me more"),
            SuggestedReply(text: "Related topics?"),
        ]
    }
}
