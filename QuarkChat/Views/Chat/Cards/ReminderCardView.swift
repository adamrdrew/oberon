import SwiftUI

struct ReminderCardView: View {
    let data: ReminderData

    var body: some View {
        HStack(spacing: 12) {
            // Priority color dot
            Circle()
                .fill(priorityColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(.headline)

                if let dueDate = data.dueDate {
                    Label {
                        Text(dueDate, style: .date)
                        Text("at")
                        Text(dueDate, style: .time)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let listName = data.listName {
                    Label(listName, systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .glassEffect(.regular.tint(.yellow.opacity(0.15)), in: .rect(cornerRadius: 16))
    }

    private var priorityColor: Color {
        switch data.priority {
        case 1: return .red
        case 5: return .orange
        case 9: return .blue
        default: return .gray
        }
    }
}
