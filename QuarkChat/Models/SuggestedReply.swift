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

    static func forDirections() -> [SuggestedReply] {
        [
            SuggestedReply(text: "How far is it?"),
            SuggestedReply(text: "Walking directions"),
        ]
    }

    static func forReminder() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Change the time"),
            SuggestedReply(text: "Add another reminder"),
        ]
    }

    static func forTimer() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Cancel the timer"),
            SuggestedReply(text: "Set another timer"),
        ]
    }

    static func forMusic() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Something similar"),
            SuggestedReply(text: "More by this artist"),
        ]
    }

    static func forTranslation() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Another language"),
            SuggestedReply(text: "How do you pronounce that?"),
        ]
    }

    static func forDefinition() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Use it in a sentence"),
            SuggestedReply(text: "What's a synonym?"),
        ]
    }

    static func forCalculation() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Round that up"),
            SuggestedReply(text: "Show as a percentage"),
        ]
    }

    static func forUnitConversion() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Convert back"),
            SuggestedReply(text: "Different unit"),
        ]
    }

    static func forSummarization() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Make it shorter"),
            SuggestedReply(text: "Key takeaways?"),
        ]
    }

    static func forContact() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Send them a message"),
            SuggestedReply(text: "Call them"),
        ]
    }

    static func forGeoSearch() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Get directions"),
            SuggestedReply(text: "Anything closer?"),
        ]
    }

    static func forPlaceAction() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Find more places"),
            SuggestedReply(text: "How far is it?"),
        ]
    }

    static func forWebSearch() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Tell me more"),
            SuggestedReply(text: "Related topics?"),
        ]
    }

    static func forChecklist() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Add more items"),
            SuggestedReply(text: "Open in Reminders"),
        ]
    }

    static func forRewriting() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Make it more formal"),
            SuggestedReply(text: "Make it shorter"),
        ]
    }

    static func forProofreading() -> [SuggestedReply] {
        [
            SuggestedReply(text: "Apply the corrections"),
            SuggestedReply(text: "Explain the changes"),
        ]
    }
}
