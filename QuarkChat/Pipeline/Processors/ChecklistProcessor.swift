import Foundation
import EventKit
import FoundationModels

struct ChecklistProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        let hasAccess = await PermissionService.shared.requestRemindersAccess()

        do {
            let session = LanguageModelSession(
                instructions: "Extract the list name and items from the user's request. Items should be comma-separated."
            )

            let response = try await session.respond(
                to: query,
                generating: ListExtraction.self
            )

            let extraction = response.content
            let listName = extraction.listName.trimmingCharacters(in: .whitespacesAndNewlines)
            let itemTexts = extraction.items
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !itemTexts.isEmpty else { return .empty }

            // If we have Reminders access, create actual reminders
            if hasAccess {
                let eventStore = await PermissionService.shared.eventStoreInstance
                for item in itemTexts {
                    let reminder = EKReminder(eventStore: eventStore)
                    reminder.title = item
                    reminder.calendar = eventStore.defaultCalendarForNewReminders()
                    try? eventStore.save(reminder, commit: false)
                }
                try? eventStore.commit()
            }

            let listItems = itemTexts.map { ListData.ListItem(text: $0) }
            let listData = ListData(title: listName, items: listItems)

            let openAction = RichAction(
                type: .openReminders,
                label: "Open in Reminders",
                subtitle: listName,
                urlString: "x-apple-reminderkit://"
            )

            let enrichment = hasAccess
                ? "Created checklist '\(listName)' with \(itemTexts.count) items in Reminders."
                : "Here's your checklist '\(listName)' with \(itemTexts.count) items. (Grant Reminders access to save them.)"

            return DomainResult(
                enrichmentText: enrichment,
                citations: [],
                actions: hasAccess ? [openAction] : [],
                richContent: [.list(listData)],
                suggestedReplies: SuggestedReply.forChecklist()
            )
        } catch {
            return .empty
        }
    }
}
