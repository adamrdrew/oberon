import Foundation
import EventKit
import FoundationModels

struct ReminderProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        // Request permission
        let hasAccess = await PermissionService.shared.requestRemindersAccess()
        guard hasAccess else {
            return DomainResult(
                enrichmentText: "I need access to Reminders to create reminders. Please grant permission in Settings > Privacy > Reminders.",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }

        // Extract reminder details via guided generation
        do {
            let now = ISO8601DateFormatter().string(from: Date())
            let session = LanguageModelSession(
                instructions: "Extract the reminder details. Current date/time: \(now). Convert relative dates to ISO 8601."
            )

            let response = try await session.respond(
                to: query,
                generating: ReminderExtraction.self
            )

            let extraction = response.content
            let title = extraction.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return .empty }

            // Create the actual reminder
            let eventStore = await PermissionService.shared.eventStoreInstance
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = title
            reminder.calendar = eventStore.defaultCalendarForNewReminders()

            // Parse priority
            switch extraction.priority {
            case "high": reminder.priority = 1
            case "medium": reminder.priority = 5
            case "low": reminder.priority = 9
            default: reminder.priority = 0
            }

            // Parse due date
            var dueDate: Date?
            if !extraction.dateTime.isEmpty {
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: extraction.dateTime) {
                    dueDate = date
                } else {
                    // Try without fractional seconds
                    isoFormatter.formatOptions = [.withInternetDateTime]
                    dueDate = isoFormatter.date(from: extraction.dateTime)
                }

                if let date = dueDate {
                    let alarm = EKAlarm(absoluteDate: date)
                    reminder.addAlarm(alarm)
                    reminder.dueDateComponents = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: date
                    )
                }
            }

            try eventStore.save(reminder, commit: true)

            // Build rich content
            let reminderData = ReminderData(
                title: title,
                dueDate: dueDate,
                priority: reminder.priority,
                listName: reminder.calendar?.title
            )

            let openAction = RichAction(
                type: .openReminders,
                label: "Open in Reminders",
                subtitle: title,
                urlString: "x-apple-reminderkit://"
            )

            var enrichment = "Created reminder: '\(title)'"
            if let date = dueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                enrichment += " for \(formatter.string(from: date))"
            }

            return DomainResult(
                enrichmentText: enrichment,
                citations: [],
                actions: [openAction],
                richContent: [.reminder(reminderData)],
                suggestedReplies: SuggestedReply.forReminder()
            )
        } catch {
            return DomainResult(
                enrichmentText: "Failed to create reminder: \(error.localizedDescription)",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }
    }
}
