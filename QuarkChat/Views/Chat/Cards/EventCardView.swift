import SwiftUI

struct EventCardView: View {
    let data: EventData

    var body: some View {
        HStack(spacing: 12) {
            // Calendar color dot
            Circle()
                .fill(Color(hex: data.calendarColor) ?? .blue)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(.headline)

                Text(data.startDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text(data.startDate, style: .time)
                    if let endDate = data.endDate {
                        Text("–")
                        Text(endDate, style: .time)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let location = data.location {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .glassEffect(.regular.tint(.red.opacity(0.15)), in: .rect(cornerRadius: 16))
    }
}

