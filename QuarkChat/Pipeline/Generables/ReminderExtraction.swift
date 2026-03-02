import Foundation
import FoundationModels

@Generable
struct ReminderExtraction {
    @Guide(description: "The reminder title — what to remember, e.g. 'Buy milk'")
    var title: String

    @Guide(description: "Due date/time in ISO 8601 format (e.g. 2026-03-03T17:00:00). Empty if no time specified.")
    var dateTime: String

    @Guide(description: "Priority level", .anyOf(["none", "low", "medium", "high"]))
    var priority: String
}
