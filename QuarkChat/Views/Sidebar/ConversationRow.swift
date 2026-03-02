import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 8) {
            // Accent dot for recently active conversations
            Circle()
                .fill(.tint)
                .frame(width: 6, height: 6)
                .opacity(recentIndicatorOpacity)

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    if let lastMessage = conversation.sortedMessages.last {
                        Text(lastMessage.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(relativeTimestamp(for: conversation.updatedAt))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
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

    // MARK: - Recent Indicator

    /// Full opacity for conversations updated within the last hour, fading to zero by 2 hours
    private var recentIndicatorOpacity: Double {
        let elapsed = Date().timeIntervalSince(conversation.updatedAt)
        if elapsed < 3600 { return 1.0 }
        if elapsed < 7200 { return 1.0 - (elapsed - 3600) / 3600 }
        return 0
    }
}
