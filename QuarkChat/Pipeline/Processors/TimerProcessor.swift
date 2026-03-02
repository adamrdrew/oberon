import Foundation
import UserNotifications
import FoundationModels

struct TimerProcessor: Sendable {

    func process(query: String) async -> DomainResult {
        // Request notification permission
        let hasAccess = await PermissionService.shared.requestNotificationAccess()
        guard hasAccess else {
            return DomainResult(
                enrichmentText: "I need notification permission to set timers. Please grant permission in Settings > Notifications.",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }

        do {
            let session = LanguageModelSession(
                instructions: "Extract timer duration and label from the user's request. Convert to total seconds."
            )

            let response = try await session.respond(
                to: query,
                generating: TimerExtraction.self
            )

            let extraction = response.content
            let seconds = extraction.durationSeconds
            guard seconds > 0 else { return .empty }

            let label = extraction.label.isEmpty ? "Timer" : extraction.label
            let durationLabel = extraction.durationLabel

            // Schedule notification
            let content = UNMutableNotificationContent()
            content.title = "Timer Complete"
            content.body = label == "Timer" ? "Your \(durationLabel) timer is done!" : "\(label) — \(durationLabel) timer is done!"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
            let request = UNNotificationRequest(
                identifier: "timer-\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )

            try await UNUserNotificationCenter.current().add(request)

            let fireDate = Date().addingTimeInterval(TimeInterval(seconds))
            let timerData = TimerData(
                label: label,
                durationSeconds: seconds,
                fireDate: fireDate
            )

            return DomainResult(
                enrichmentText: "Timer set for \(durationLabel)\(label != "Timer" ? " (\(label))" : ""). You'll be notified when it's done.",
                citations: [],
                actions: [],
                richContent: [.timer(timerData)],
                suggestedReplies: SuggestedReply.forTimer()
            )
        } catch {
            return DomainResult(
                enrichmentText: "Failed to set timer: \(error.localizedDescription)",
                citations: [],
                actions: [],
                richContent: [],
                suggestedReplies: []
            )
        }
    }
}
