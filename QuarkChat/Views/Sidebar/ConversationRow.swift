import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(OTheme.conversationTitle)
                .lineLimit(1)

            HStack {
                if let lastMessage = conversation.sortedMessages.last {
                    Text(lastMessage.content)
                        .font(OTheme.conversationPreview)
                        .foregroundStyle(OTheme.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(relativeTimestamp(for: conversation.updatedAt))
                    .font(OTheme.timestamp)
                    .foregroundStyle(OTheme.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Relative Timestamp

    private func relativeTimestamp(for date: Date) -> String {
        let now = Date()
        let elapsed = now.timeIntervalSince(date)

        if elapsed < 60 {
            return "Just now"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m"
        } else if elapsed < 86400 {
            return "\(Int(elapsed / 3600))h"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else if elapsed < 604800 { // within 7 days
            return date.formatted(.dateTime.weekday(.abbreviated))
        } else if Calendar.current.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day().year())
        }
    }
}
